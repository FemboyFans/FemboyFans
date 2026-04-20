# frozen_string_literal: true

module Middleware
  class JsonLog
    def initialize(app)
      @app = app
      @path = Rails.root.join("log", "requests.#{Rails.env}.jsonl")
    end

    def call(env)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      request = ActionDispatch::Request.new(env)

      status = headers = body = exception = nil

      begin
        status, headers, body = @app.call(env)
      rescue => e # rubocop:disable Style/RescueStandardError
        exception = e
        raise
      ensure
        line = content(env, request: request, start: started_at, status: status, headers: headers, body: body, exception: exception)

        File.open(@path, "a") do |f|
          f.flock(File::LOCK_EX)
          f.puts(line.to_json)
        end
      end

      [status, headers, body]
    end

    private

    def content(env, request:, start:, status:, headers:, body:, exception:) # rubocop:disable Lint/UnusedMethodArgument
      exception ||= env["action_dispatch.exception"]
      duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(3)
      request_headers = extract_request_headers(env)
      request_body_size = calculate_request_body_size(env, request)
      response_headers = headers ? headers.to_h : {}
      response_body_size = calculate_response_body_size(response_headers, body)
      json = {
        time:               Time.now.utc.iso8601(6),
        request_id:         request.request_id,
        method:             request.request_method,
        path:               request.fullpath,
        ip:                 request.remote_ip,
        user_agent:         request.user_agent,
        referer:            request.referer,
        status:             status,
        duration:           duration,
        request_body_size:  request_body_size,
        total_request_size: calculate_total_request_size(env, request, request_headers, request_body_size),
        request_headers:    request_headers,
        response_body_size: response_body_size,
        total_response_size: calculate_total_response_size(status, response_headers, response_body_size),
        response_headers:   response_headers,
        exception:          nil,
      }

      if exception
        json[:exception] = {
          class:   exception.class.name,
          message: exception.message,
        }
      end

      json
    end

    def calculate_request_body_size(env, request)
      return env["CONTENT_LENGTH"].to_i if env["CONTENT_LENGTH"].present?

      body = request.body
      return 0 if body.nil?

      body.rewind if body.respond_to?(:rewind)
      size = body.read.to_s.bytesize
      body.rewind if body.respond_to?(:rewind)
      size
    end

    def calculate_total_request_size(env, request, request_headers, request_body_size)
      protocol = env["HTTP_VERSION"] || env["SERVER_PROTOCOL"] || "HTTP/1.1"
      request_line_size = "#{request.request_method} #{request.fullpath} #{protocol}\r\n".bytesize
      headers_size = request_headers.sum { |key, value| "#{key}: #{value}\r\n".bytesize }

      request_line_size + headers_size + "\r\n".bytesize + request_body_size
    end

    def calculate_response_body_size(response_headers, body)
      return response_headers["Content-Length"].to_i if response_headers["Content-Length"].present?
      return body.body.to_s.bytesize if body.respond_to?(:body)
      return body.sum { |chunk| chunk.to_s.bytesize } if body.is_a?(Array)

      nil
    end

    def calculate_total_response_size(status, response_headers, response_body_size)
      return if status.nil? || response_body_size.nil?

      status_line_size = "HTTP/1.1 #{status} #{Rack::Utils::HTTP_STATUS_CODES[status.to_i]}\r\n".bytesize
      headers_size = response_headers.sum { |key, value| "#{key}: #{value}\r\n".bytesize }

      status_line_size + headers_size + "\r\n".bytesize + response_body_size
    end

    def extract_request_headers(env)
      env.each_with_object({}) do |(key, value), headers|
        case key
        when "CONTENT_TYPE"
          headers["Content-Type"] = value
        when "CONTENT_LENGTH"
          headers["Content-Length"] = value
        when /\AHTTP_/
          name = key.delete_prefix("HTTP_").split("_").map(&:capitalize).join("-")
          headers[name] = value
        end
      end
    end
  end
end
