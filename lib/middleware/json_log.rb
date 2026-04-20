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
      json = {
        time:             Time.now.utc.iso8601(6),
        request_id:       request.request_id,
        method:           request.request_method,
        path:             request.fullpath,
        ip:               request.remote_ip,
        user_agent:       request.user_agent,
        referer:          request.referer,
        status:           status,
        duration:         duration,
        request_size:     request.content_length || request.raw_post.bytesize,
        request_headers:  extract_request_headers(env),
        response_size:    headers&.[]("Content-Length")&.to_i,
        response_headers: headers ? headers.to_h : {},
        exception:        nil,
      }

      if exception
        json[:exception] = {
          class:   exception.class.name,
          message: exception.message,
        }
      end

      json
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
