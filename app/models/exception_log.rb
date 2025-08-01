# frozen_string_literal: true

class ExceptionLog < ApplicationRecord
  serialize(:extra_params, coder: JSON)

  def self.add!(exception, user_id: nil, request: nil, source: nil, **extra)
    source ||= request.present? ? request.filtered_parameters.slice(:controller, :action).values.join("#") : "Unknown"
    extra_params = {
      host:       Socket.gethostname,
      params:     request.try(:filtered_parameters),
      user_id:    user_id,
      referrer:   request.try(:referrer),
      user_agent: request.try(:user_agent) || "Internal",
      source:     source,
      **extra,
    }

    # Required to unwrap exceptions that occur inside template rendering.
    unwrapped_exception = exception
    if exception.is_a?(ActionView::Template::Error)
      unwrapped_exception = exception.cause
    end

    if unwrapped_exception.is_a?(ActiveRecord::QueryCanceled)
      extra_params[:sql] = {}
      extra_params[:sql][:query] = unwrapped_exception&.sql || "[NOT FOUND?]"
      extra_params[:sql][:binds] = unwrapped_exception&.binds&.map(&:value_for_database)
    end

    create!(
      ip_addr:      request.try(:remote_ip) || "0.0.0.0",
      class_name:   unwrapped_exception.class.name,
      message:      unwrapped_exception.message,
      trace:        unwrapped_exception.backtrace.try(:join, "\n") || "",
      code:         SecureRandom.uuid,
      version:      GitHelper.instance.local.short_commit,
      extra_params: extra_params,
    )
  rescue ActiveRecord::StatementInvalid => e
    TraceLogger.error("ExceptionLog", "Failed to log exception: #{e.message}")
    TraceLogger.error(exception)
  end

  def user
    User.find_by(id: extra_params["user_id"])
  end

  def self.search(params, user)
    q = super

    if params[:commit].present?
      q = q.where(version: params[:commit])
    end

    if params[:class_name].present?
      q = q.where(class_name: params[:class_name])
    end

    if params[:without_class_name].present?
      q = q.where.not(class_name: params[:without_class_name])
    end

    q.apply_basic_order(params)
  end
end
