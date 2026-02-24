# frozen_string_literal: true

class PostFilesStatus
  attr_accessor(:missing, :backup_missing, :errors)

  def initialize
    @missing = []
    @errors = []
    @backup_missing = []
  end

  def load
    Post.not_deleted.with_assets.find_in_batches.each do |batch|
      values = Cache.read_multi(batch.map { |p| "#{p.id}:#{p.md5}" }, "filestatus:missing")
      batch.reject { |p| values.key?("#{p.id}:#{p.md5}") }.each do |post|
        post.media_asset.variants.each do |var|
          @missing << { id: post.id, md5: post.md5, type: var.type, format: var.format }.with_open_access unless var.storage_manager.is_a?(StorageManager::Null) | var.file_exists?
          @backup_missing << { id: post.id, md5: post.md5, type: var.type, format: var.format }.with_open_access unless var.backup_storage_manager.is_a?(StorageManager::Null) || var.backup_file_exists?
        rescue StandardError => e
          @errors << { id: post.id, md5: post.md5, type: var.type, format: var.format, message: e }.with_open_access
        end
        Cache.write("filestatus:missing:#{post.id}:#{post.md5}", @missing.select { |m| m.id == post.id && m.md5 == post.md5 }, expires_in: 3.dayS)
      end
    end
    Cache.write("filestatus:missing", self, expires_in: 3.days)
    self
  end

  def self.clear_cache
    Post.not_deleted.with_assets.find_in_batches.each do |batch|
      batch.each { |post| Cache.delete("filestatus:missing:#{post.id}:#{post.md5}") }
    end
    Cache.delete("filestatus:missing")
  end

  def self.get_cached
    Cache.fetch("filestatus:missing")
  end

  def self.cached?
    get_cached != nil
  end

  def self.load!
    new.load
  end

  def self.queue
    PostFilesStatusJob.perform_later
  end

  def as_json(*)
    {
      missing:        missing,
      backup_missing: backup_missing,
      errors:         errors,
    }
  end

  def self.as_json(*)
    data = get_cached
    {
      cached: !data.nil?,
      data:   data,
    }
  end
end
