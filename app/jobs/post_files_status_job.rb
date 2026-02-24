# frozen_string_literal: true

class PostFilesStatusJob < ApplicationJob
  queue_as(:default)

  sidekiq_options(unique_for: 10.minutes, retry: 4)

  def perform
    PostFilesStatus.clear_cache
    PostFilesStatus.new.load
  end
end
