# frozen_string_literal: true

require "tmpdir"

class Upload < ApplicationRecord
  class Error < StandardError; end

  attr_accessor :as_pending, :replaced_post, :file, :original_post_id, :locked_rating, :replacement_id, :locked_tags

  belongs_to :uploader, class_name: "User"
  belongs_to :post, optional: true

  after_initialize :set_locked_tags
  before_validation :assign_rating_from_tags
  before_validation :normalize_direct_url, on: :create
  validate :uploader_is_not_limited, on: :create
  validate :direct_url_is_whitelisted, on: :create
  validates :rating, inclusion: { in: %w[q e s] }, allow_nil: false
  validate :md5_is_unique, on: :file
  validate on: :file do |upload|
    FileValidator.new(upload, file.path).validate
  end

  def set_locked_tags
    self.locked_tags ||= ""
  end

  module StatusMethods
    def is_pending?
      status == "pending"
    end

    def is_processing?
      status == "processing"
    end

    def is_completed?
      status == "completed"
    end

    def is_duplicate?
      status.match?(/duplicate: \d+/)
    end

    def is_errored?
      status.match?(/error:/)
    end

    def sanitized_status
      if is_errored?
        status.sub(/DETAIL:.+/m, "...")
      else
        status
      end
    end

    def duplicate_post_id
      @duplicate_post_id ||= status[/duplicate: (\d+)/, 1]
    end
  end

  module DirectURLMethods
    def normalize_direct_url
      return if direct_url.blank?
      self.direct_url = direct_url.unicode_normalize(:nfc)
      if direct_url =~ %r{\Ahttps?://}i
        self.direct_url = begin
          Addressable::URI.normalized_encode(direct_url)
        rescue StandardError
          direct_url
        end
      end
      self.direct_url = begin
        Sources::Strategies.find(direct_url).canonical_url
      rescue StandardError
        direct_url
      end
    end

    def direct_url_parsed
      return nil unless direct_url =~ %r{\Ahttps?://}i
      begin
        Addressable::URI.heuristic_parse(direct_url)
      rescue StandardError
        nil
      end
    end
  end

  module UploaderMethods
    def uploader_name
      User.id_to_name(uploader_id)
    end
  end

  module SearchMethods
    def pending
      where(status: "pending")
    end

    def post_tags_match(query)
      where(post_id: Post.tag_match_sql(query))
    end

    def search(params)
      q = super

      q = q.where_user(:uploader_id, :uploader, params)

      if params[:source].present?
        q = q.where(source: params[:source])
      end

      if params[:source_matches].present?
        q = q.where("uploads.source LIKE ? ESCAPE E'\\\\'", params[:source_matches].to_escaped_for_sql_like)
      end

      if params[:rating].present?
        q = q.where(rating: params[:rating])
      end

      if params[:parent_id].present?
        q = q.attribute_matches(:parent_id, params[:parent_id])
      end

      if params[:post_id].present?
        q = q.attribute_matches(:post_id, params[:post_id])
      end

      if params[:has_post].to_s.truthy?
        q = q.where.not(post_id: nil)
      elsif params[:has_post].to_s.falsy?
        q = q.where(post_id: nil)
      end

      if params[:post_tags_match].present?
        q = q.post_tags_match(params[:post_tags_match])
      end

      if params[:status].present?
        q = q.where("uploads.status LIKE ? ESCAPE E'\\\\'", params[:status].to_escaped_for_sql_like)
      end

      if params[:backtrace].present?
        q = q.where("uploads.backtrace LIKE ? ESCAPE E'\\\\'", params[:backtrace].to_escaped_for_sql_like)
      end

      if params[:tag_string].present?
        q = q.where("uploads.tag_string LIKE ? ESCAPE E'\\\\'", params[:tag_string].to_escaped_for_sql_like)
      end

      q.apply_basic_order(params)
    end
  end

  include FileMethods
  include StatusMethods
  include UploaderMethods
  extend SearchMethods
  include DirectURLMethods

  def uploader_is_not_limited
    # Uploads created when approving a replacemnet should always go through
    return if replacement_id.present?

    uploadable = uploader.can_upload_with_reason
    if uploadable != true
      errors.add(:uploader, User.upload_reason_string(uploadable))
      return false
    end
    true
  end

  def direct_url_is_whitelisted
    return true if direct_url_parsed.blank?
    valid, reason = UploadWhitelist.is_whitelisted?(direct_url_parsed)
    unless valid
      errors.add(:source, "is not whitelisted: #{reason}")
      return false
    end
    true
  end

  def md5_is_unique
    if md5.nil?
      return
    end

    if (destroyed_post = DestroyedPost.find_by(md5: md5))
      errors.add(:base, "That image had been deleted from our site, and cannot be re-uploaded")
      destroyed_post.notify_reupload(uploader)
      return
    end

    replacements = PostReplacement.pending.where(md5: md5)
    replacements = replacements.where.not(id: replacement_id) if replacement_id

    if !replaced_post && replacements.any?
      replacements.each do |rep|
        errors.add(:md5, "duplicate of pending replacement on post ##{rep.post_id}")
      end
      return
    end

    md5_post = Post.find_by(md5: md5)

    if md5_post.nil?
      return
    end

    if replaced_post && replaced_post == md5_post
      return
    end

    errors.add(:md5, "duplicate: #{md5_post.id}")
  end

  def assign_rating_from_tags
    if (rating = TagQuery.fetch_metatag(tag_string, "rating"))
      self.rating = rating.downcase.first
    end
  end

  def presenter
    @presenter ||= UploadPresenter.new(self)
  end

  def upload_as_pending?
    as_pending.to_s.truthy?
  end

  def self.available_includes
    %i[post uploader]
  end

  def visible?(user = CurrentUser.user)
    user.is_janitor?
  end
end
