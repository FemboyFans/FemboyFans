# frozen_string_literal: true

class AudioTrack < ApplicationRecord
  has_media_asset(:audio_track_media_asset)

  belongs_to(:post)
  belongs_to_user(:creator, ip: true, clones: :updater)
  resolvable(:updater)
  resolvable(:destroyer)
  belongs_to_user(:approver, optional: true)
  belongs_to_user(:rejector, optional: true)
  # is_system_generated: virtual, not persisted - set by AudioTrackExtractionJob when creating
  # the auto-extracted default track, so it can skip the suggestion-queue rules below without
  # that being tied to *who* ends up credited as creator (which is the post's uploader, same as
  # PostReplacement's auto-generated backup - see #create_backup_replacement).
  attr_accessor(:file, :direct_url, :is_system_generated)

  # How much longer than the post's own video a suggested track may run before it's rejected as
  # mismatched. Only checked one-directional - a video can have a long silent/no-audio tail, so a
  # shorter track is fine, but a track running past the video's end can't be a real match for it.
  MAX_DURATION_OVERAGE = 1.0

  validate(:user_is_not_limited, on: :create)
  validate(:post_is_valid, on: :create)
  validate(:direct_url_is_whitelisted, on: :create)
  validates(:label, presence: true, length: { maximum: 100 })
  validates(:reason, length: { minimum: 5, maximum: 150 }, presence: true, on: :create, unless: :is_system_generated?)
  validates(:rejection_reason, length: { maximum: 150 }, if: :rejected?)
  validate(:validate_media_asset_status, on: :create)
  validate(:duration_matches_post, on: :create, unless: :is_system_generated?)

  before_create(:fill_sequence_number)
  before_create(:fill_file_md5)
  after_create(-> { post.update_index })
  before_destroy(:log_destroy)
  after_destroy(-> { post.update_index })
  after_commit(:delete_files, on: :destroy)

  enum(:status, %w[uploading pending approved rejected].index_with(&:to_s))
  scope(:default, -> { where(is_default: true) })
  # The only tracks that actually apply right now - a post replacement changes posts.md5, which
  # makes tracks tied to the old file stop matching (and a later revert back to that file makes
  # them match again) with no separate disable/restore step needed.
  scope(:for_current_file, -> { joins(:post).where("audio_tracks.file_md5 = posts.md5") })

  def is_system_generated?
    is_system_generated.to_s.truthy?
  end

  def delete_files
    media_asset&.expunge!(destroyer)
  end

  def validate_media_asset_status
    status = media_asset.status
    status_message = media_asset.pretty_status
    return unless %w[duplicate failed expunged].include?(status)
    errors.add(:base, status_message)
  end

  def duration_matches_post
    return if media_asset.duration.blank? || post.duration.blank?
    return if media_asset.duration - post.duration <= MAX_DURATION_OVERAGE
    errors.add(:base, "duration (#{media_asset.duration.round(1)}s) can't be more than #{MAX_DURATION_OVERAGE}s longer than the post's duration (#{post.duration.round(1)}s)")
  end

  def direct_url_parsed
    return nil unless direct_url =~ %r{\Ahttps?://}i
    begin
      Addressable::URI.heuristic_parse(direct_url)
    rescue Addressable::URI::InvalidURIError
      nil
    end
  end

  def direct_url_is_whitelisted
    return true if direct_url_parsed.blank?
    valid, reason = UploadWhitelist.is_whitelisted?(direct_url_parsed, creator)
    unless valid
      errors.add(:source, "is not whitelisted: #{reason}")
      return false
    end
    true
  end

  def self.calculate_sequence_number(post_id)
    1 + where(post_id: post_id).maximum(:sequence_number).to_i
  end

  def fill_sequence_number
    self.sequence_number = self.class.calculate_sequence_number(post_id)
  end

  def fill_file_md5
    self.file_md5 ||= post.md5
  end

  module PostMethods
    def post_is_valid
      if post.is_deleted?
        errors.add(:post, "is deleted")
        false
      elsif !post.is_video?
        errors.add(:post, "is not a video")
        false
      end
    end
  end

  def user_is_not_limited
    return true if is_system_generated?
    uploadable = creator.can_upload_with_reason
    if uploadable != true
      errors.add(:creator, User.upload_reason_string(uploadable))
      throw(:abort)
    end

    # Janitor bypass, matching PostReplacement's rate limit carve-out.
    return true if creator.is_janitor?

    if post.audio_tracks.for_creator(creator_id).where.gt(created_at: 1.day.ago).count > AdminConfig.instance.audio_track_per_day_limit
      errors.add(:creator, "has already suggested too many audio tracks for this post today")
      throw(:abort)
    end
    if post.audio_tracks.pending.for_creator(creator_id).count > AdminConfig.instance.audio_track_per_post_limit
      errors.add(:creator, "already has too many pending audio track suggestions for this post")
      throw(:abort)
    end
    true
  end

  def log_destroy
    PostEvent.add!(post_id, destroyer, :audio_track_deleted, audio_track_id: id)
  end

  module ProcessingMethods
    def approve!(approver, set_default: false)
      unless pending?
        errors.add(:status, "must be pending to approve")
        return
      end

      transaction do
        post.audio_tracks.default.approved.where(file_md5: file_md5).where.not(id: id).update_all(is_default: false) if set_default.to_s.truthy?

        self.status = "approved"
        self.approver = approver
        self.updater = approver
        self.is_default = true if set_default.to_s.truthy?
        save!

        PostEvent.add!(post.id, approver, :audio_track_accepted, audio_track_id: id)
      end
      post.update_index
    end

    def reject!(user, reason = "")
      unless pending?
        errors.add(:status, "must be pending to reject")
        return
      end

      PostEvent.add!(post.id, user, :audio_track_rejected, audio_track_id: id)
      update(status: "rejected", rejector: user, rejection_reason: reason)
      post.update_index
    end

    def set_default!(approver)
      unless approved?
        errors.add(:status, "must be approved to set as default")
        return
      end

      transaction do
        post.audio_tracks.default.approved.where(file_md5: file_md5).where.not(id: id).update_all(is_default: false)
        update!(is_default: true, updater: approver)
      end
    end
  end

  module StorageMethods
    def track_file_url(user)
      media_asset.file_url(user: user)
    end
  end

  module SearchMethods
    def query_dsl
      super
        .field(:label)
        .field(:status)
        .field(:post_id)
        .field(:is_default)
        .field(:file_md5)
        .field(:ip_addr, :creator_ip_addr)
        .association(:creator)
        .association(:approver)
        .association(:rejector)
    end

    def default_order
      order(arel_case(:status).when("pending").then(0).else(1).asc, id: :desc)
    end
  end

  include(StorageMethods)
  include(ProcessingMethods)
  include(PostMethods)
  extend(SearchMethods)

  def visible?(user)
    return false unless post.visible?(user)
    return true if user.is_staff? || user.id == creator_id
    !rejected?
  end

  # False once the post's file has moved on (a replacement) - see .for_current_file. A track
  # for an old file isn't gone, it's just inert until/unless the post reverts back to that file.
  def for_current_file?
    file_md5 == post.md5
  end

  def file_url(user)
    track_file_url(user) if post.visible?(user)
  end

  def apionly_file_url
    file_url(CurrentUser.user)
  end

  def self.available_includes
    %i[creator approver rejector post]
  end
end
