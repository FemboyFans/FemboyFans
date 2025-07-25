# frozen_string_literal: true

class Comment < ApplicationRecord
  RECENT_COUNT = 6
  include(UserWarnable)
  simple_versioning
  mentionable
  belongs_to_user(:creator, ip: true, clones: :updater, counter_cache: "comment_count")
  belongs_to_user(:updater, ip: true)
  belongs_to_user(:warning_user, optional: true)
  resolvable(:destroyer)
  normalizes(:body, with: ->(body) { body.gsub("\r\n", "\n") })
  validate(:validate_post_exists, on: :create)
  validate(:validate_creator_is_not_limited, on: :create)
  validate(:post_not_comment_restricted, on: :create)
  validates(:body, presence: { message: "has no content" })
  validates(:body, length: { minimum: 1, maximum: FemboyFans.config.comment_max_size })

  before_create(:auto_report_spam)
  after_create(:update_last_commented_at_on_create)
  after_update(if: ->(rec) { !rec.saved_change_to_is_hidden? && updater_id != rec.creator_id }) do |rec|
    ModAction.log!(updater, :comment_update, rec, user_id: rec.creator_id)
  end
  after_destroy(:update_last_commented_at_on_destroy)
  after_destroy do |rec|
    ModAction.log!(destroyer, :comment_delete, rec, user_id: rec.creator_id, post_id: rec.post_id)
  end
  after_save(:update_last_commented_at_on_destroy, if: ->(rec) { rec.is_hidden? && rec.saved_change_to_is_hidden? })
  after_save(if: ->(rec) { rec.saved_change_to_is_hidden? && updater_id != rec.creator_id }) do |rec|
    action = rec.is_hidden? ? :comment_hide : :comment_unhide
    ModAction.log!(updater, action, rec, user_id: rec.creator_id)
  end

  belongs_to(:post, counter_cache: :comment_count)
  has_many(:votes, class_name: "CommentVote", dependent: :destroy)
  has_many(:tickets, as: :model)
  has_many(:versions, class_name: "EditHistory", as: :versionable, dependent: :destroy)
  has_one(:spam_ticket, -> { spam }, class_name: "Ticket", as: :model)

  scope(:deleted, -> { where(is_hidden: true) })
  scope(:not_deleted, -> { where(is_hidden: false) })
  scope(:stickied, -> { where(is_sticky: true) })
  scope(:for_creator, ->(user) { where(creator_id: u2id(user)) })

  module SearchMethods
    def recent
      reorder("comments.id desc").limit(RECENT_COUNT)
    end

    def hidden(user)
      if user.is_moderator?
        where("not(comments.score >= ? or comments.is_sticky = true)", user.comment_threshold)
      else
        where("not((comments.score >= ? or comments.is_sticky = true) and (comments.is_hidden = false or comments.creator_id = ?))", user.comment_threshold, user.id)
      end
    end

    def post_tags_match(query, user)
      where(post_id: Post.tag_match_sql(query, user).order(id: :desc).limit(300))
    end

    def search(params, user)
      q = super.includes(:creator).includes(:updater).includes(:post)

      q = q.attribute_matches(:body, params[:body_matches])

      if params[:post_id].present?
        q = q.where("post_id in (?)", params[:post_id].split(",").map(&:to_i))
      end

      if params[:post_tags_match].present?
        q = q.post_tags_match(params[:post_tags_match], user)
      end

      with_resolved_user_ids(:post_note_updater, params) do |user_ids|
        q = q.where(post_id: NoteVersion.select(:post_id).where(updater_id: user_ids))
      end

      q = q.where_user(:creator_id, :creator, params)

      if params[:ip_addr].present?
        q = q.where("creator_ip_addr <<= ?", params[:ip_addr])
      end

      q = q.attribute_matches(:is_hidden, params[:is_hidden])
      q = q.attribute_matches(:is_sticky, params[:is_sticky])

      case params[:order]
      when "post_id", "post_id_desc"
        q = q.order("comments.post_id DESC, comments.created_at DESC")
      when "score", "score_desc"
        q = q.order("comments.score DESC, comments.created_at DESC")
      when "updated_at", "updated_at_desc"
        q = q.order("comments.updated_at DESC")
      else
        # Force a better query plan
        if %i[body_matches creator_name creator_id].any? { |key| params[key].present? }
          q = q.order(created_at: :desc)
        else
          q = q.apply_basic_order(params)
        end
      end

      q.where_user(:"posts.uploader_id", :poster, params) do |condition, _ids|
        condition = condition.joins(:post)
        # Force a better query plan by ordering by created_at
        condition.reorder("comments.created_at desc")
      end
    end
  end

  extend(SearchMethods)

  def validate_post_exists
    errors.add(:post, "must exist") unless Post.exists?(post_id)
  end

  def validate_creator_is_not_limited
    allowed = creator.can_comment_with_reason
    if allowed != true
      errors.add(:creator, User.throttle_reason(allowed))
      return false
    end
    true
  end

  def post_not_comment_restricted
    errors.add(:base, "Post has comments disabled") if !updater.is_moderator? && Post.find_by(id: post_id)&.is_comment_disabled?
    return if updater.is_moderator?
    post = Post.find_by(id: post_id)
    return if post.blank?
    errors.add(:base, "Post has comments locked") if post.is_comment_locked?
    errors.add(:base, "Post has comments disabled") if post.is_comment_disabled?
  end

  def update_last_commented_at_on_create
    post = Post.find(post_id)
    return unless post
    post.update_column(:last_commented_at, created_at)
    if Comment.where("post_id = ?", post_id).count <= FemboyFans.config.comment_threshold && !do_not_bump_post?
      post.update_column(:last_comment_bumped_at, created_at)
    end
    post.update_index
    true
  end

  def update_last_commented_at_on_destroy
    post = Post.find(post_id)
    return unless post
    other_comments = Comment.where("post_id = ? and id <> ?", post_id, id).order("id DESC")
    if other_comments.none?
      post.update_columns(last_commented_at: nil)
    else
      post.update_columns(last_commented_at: other_comments.first.created_at)
    end

    if other_comments.none?
      post.update_columns(last_comment_bumped_at: nil)
    else
      post.update_columns(last_comment_bumped_at: other_comments.first.created_at)
    end
    post.update_index
    true
  end

  def below_threshold?(user)
    score < user.comment_threshold
  end

  def can_reply?(user)
    return false if is_sticky?
    return false if (post.is_comment_locked? || post.is_comment_disabled?) && !user.is_moderator?
    true
  end

  def editable_by?(user)
    return true if user.is_admin?
    return false if (post.is_comment_locked? || post.is_comment_disabled?) && !user.is_moderator?
    return false if was_warned?
    creator_id == user.id
  end

  def can_hide?(user)
    return true if user.is_moderator?
    return false if !visible_to?(user) || was_warned? || post&.is_comment_disabled?
    user.id == creator_id
  end

  def visible_to?(user)
    return true if user.is_moderator?
    return false if !is_sticky? && post&.is_comment_disabled? && creator_id != user.id
    return false if post.is_comment_disabled?
    return true if is_hidden? == false
    creator_id == user.id # Can always see your own comments, even if hidden.
  end

  def should_see?(user)
    return user.show_hidden_comments? if creator_id == user.id && is_hidden?
    visible_to?(user)
  end

  def hide!(user)
    update(is_hidden: true, updater: user)
  end

  def unhide!(user)
    update(is_hidden: false, updater: user)
  end

  def hidden_at
    return nil unless is_hidden?
    versions.hidden.last&.created_at
  end

  def warned_at
    return nil unless was_warned?
    versions.marked.last&.created_at
  end

  def edited_version
    versions.edited.last
  end

  def edited_at
    edited_version&.created_at
  end

  def auto_report_spam
    if SpamDetector.new(self, user_ip: creator_ip_addr.to_s).spam?
      self.is_spam = true
      tickets << Ticket.new(creator: User.system, creator_ip_addr: "127.0.0.1", reason: "Spam.")
    end
  end

  def mark_spam!(user)
    return if is_spam?
    update!(is_spam: true, updater: user)
    return if spam_ticket.present?
    SpamDetector.new(self, user_ip: creator_ip_addr.to_s).spam!
  end

  def mark_not_spam!(user)
    return unless is_spam?
    update!(is_spam: false, updater: user)
    return if spam_ticket.blank?
    SpamDetector.new(self, user_ip: creator_ip_addr.to_s).ham!
  end

  def self.available_includes
    %i[creator post updater]
  end

  def visible?(user)
    user.is_moderator? || !is_hidden? || creator_id == user.id
  end
end
