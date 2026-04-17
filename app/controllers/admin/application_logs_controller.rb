# frozen_string_literal: true

module Admin
  class ApplicationLogsController < ApplicationController
    before_action(:ensure_enabled)

    def index
      @log = authorize(Admin::ApplicationLog.new)
      @entries = @log.entries(page: params[:page], limit: params[:limit])
    end

    def status
      @log = authorize(Admin::ApplicationLog.new, :index?)
      previous_count = params[:count].to_i
      total_count = @log.total_count

      render(json: {
        total_count: total_count,
        new_lines:   [total_count - previous_count, 0].max,
      })
    end

    private

    def ensure_enabled
      access_denied("This feature is disabled") unless FemboyFans.config.enable_application_logs?
    end
  end
end
