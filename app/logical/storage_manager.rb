# frozen_string_literal: true

module StorageManager
  class Error < StandardError; end

  DEFAULT_BASE_DIR = Rails.public_path.join("data").to_s
end
