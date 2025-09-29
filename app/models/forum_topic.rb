# frozen_string_literal: true

class ForumTopic < ApplicationRecord
  class MergeError < StandardError; end

  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)
  belongs_to(:category, class_name: "ForumCategory", counter_cache: "topic_count")
  belongs_to(:merge_target, class_name: "ForumTopic", optional: true)
  has_many(:posts, -> { order(id: :asc) }, class_name: "ForumPost", foreign_key: "topic_id", dependent: :destroy)
  has_one(:original_post, -> { order(id: :asc) }, class_name: "ForumPost", foreign_key: "topic_id", inverse_of: :topic)
  has_one(:last_post, -> { order(id: :desc) }, class_name: "ForumPost", foreign_key: "topic_id", inverse_of: :topic)
  has_many(:statuses, class_name: "ForumTopicStatus")
  before_validation(:initialize_original_post_creator, on: :create)
  before_validation(:initialize_is_hidden, on: :create)
  validate(:category_valid)
  validates(:title, :creator_id, presence: true)
  validates_associated(:original_post, message: ->(topic, meta) { format_associated_message(topic, meta, :original_post) })
  validates(:original_post, presence: true, unless: :is_merged?)
  validates(:title, length: { minimum: 1, maximum: 250 })
  validate(:category_allows_creation, on: :create)
  validate(:validate_not_aibur, if: :will_save_change_to_is_hidden?)
  accepts_nested_attributes_for(:original_post)
  after_update(:update_original_post, unless: :is_merging)
  before_destroy(:set_posts_destroyer, prepend: true)
  after_destroy(:log_delete)
  after_commit(:log_save, on: %i[create update], unless: :is_merging)
  after_update(if: :saved_change_to_title?) do
    Cache.delete("topic_name:#{id}")
  end

  attribute(:category_id, :integer, default: -> { FemboyFans.config.default_forum_category })

  attr_accessor(:is_merging, :target_topic_id)

  def validate_not_aibur
    return if updater.is_moderator? || !original_post&.is_aibur?

    if is_hidden?
      errors.add(:topic, "is for an alias, implication, or bulk update request. It cannot be hidden")
      throw(:abort)
    end
  end

  module CategoryMethods
    extend(ActiveSupport::Concern)

    module ClassMethods
      def for_category_id(cid)
        where(category_id: cid)
      end
    end

    def category_name
      return "(Unknown)" unless category
      category.name
    end

    def category_valid
      return if category
      errors.add(:category, "is invalid")
      throw(:abort)
    end

    def category_allows_creation
      if category && !category.can_create_within?(creator)
        errors.add(:category, "does not allow new topics")
        false
      end
    end
  end

  module LogMethods
    def log_save
      specific = false
      if saved_change_to_is_hidden?
        specific = true
        ModAction.log!(updater, is_hidden? ? :forum_topic_hide : :forum_topic_unhide, self, forum_topic_title: title, user_id: creator_id)
      end

      if saved_change_to_is_locked?
        specific = true
        ModAction.log!(updater, is_locked? ? :forum_topic_lock : :forum_topic_unlock, self, forum_topic_title: title, user_id: creator_id)
      end

      if saved_change_to_is_sticky?
        specific = true
        ModAction.log!(updater, is_sticky? ? :forum_topic_stick : :forum_topic_unstick, self, forum_topic_title: title, user_id: creator_id)
      end

      if saved_change_to_category_id? && !previously_new_record?
        specific = true
        ModAction.log!(updater, :forum_topic_move, self, forum_topic_title: title, user_id: creator_id, forum_category_id: category_id, forum_category_name: category.name, old_forum_category_id: category_id_before_last_save, old_forum_category_name: ForumCategory.find_by(id: category_id_before_last_save)&.name || "")
      end

      unless specific || previously_new_record? || updater.id == creator_id
        ModAction.log!(updater, :forum_topic_update, self, forum_topic_title: title, user_id: creator_id)
      end
    end

    def log_delete
      ModAction.log!(destroyer, :forum_topic_delete, self, forum_topic_title: title, user_id: creator_id)
    end
  end

  module SearchMethods
    def unmuted(user)
      left_outer_joins(:statuses).where("forum_topic_statuses.mute": false, "forum_topic_statuses.user_id": u2id(user)).or(left_outer_joins(:statuses).where("forum_topic_statuses.id": nil))
    end

    def sticky_first
      order(is_sticky: :desc, last_post_created_at: :desc)
    end

    def default_order
      order(last_post_created_at: :desc)
    end

    def apply_order(params)
      order_with({
        sticky:               { is_sticky: :desc },
        last_post_created_at: { last_post_created_at: :desc },
      }, params[:order], secondary: { last_post_created_at: :desc })
    end

    def query_dsl
      super
        .field(:title_matches, :title)
        .field(:title)
        .field(:category_id)
        .field(:is_sticky)
        .field(:is_locked)
        .field(:is_hidden)
        .field(:creator_ip_addr)
        .field(:updater_ip_addr)
        .association(:creator)
        .association(:updater)
    end
  end

  module VisitMethods
    def read_by?(user)
      return true if user.is_anonymous?

      return true if user_mute(user)
      last_read_at = category.last_read_at_for(user)

      (last_read_at && last_post_created_at <= last_read_at) || false
    end

    def muted_by?(user)
      return false if user.is_anonymous?

      m = user_mute(user)
      m.is_a?(ActiveRecord::Relation) ? m.exists? : m.present?
    end

    def mark_as_read!(user)
      return if user.is_anonymous?

      category.mark_topic_as_read!(user, self)
    end
  end

  module SubscriptionMethods
    def user_subscription(user)
      statuses.find_by(user_id: user.id, subscription: true)
    end
  end

  module MuteMethods
    # TODO: revisit muting, it may need to be further optimized or removed due to performance issues
    def user_mute(user)
      if association(:statuses).loaded?
        statuses.find { |s| s.mute? && s.user_id == user.id }
      else
        statuses.find_by(user_id: user.id, mute: true)
      end
    end
  end

  module MergeMethods
    def merge_into!(topic, user)
      raise(MergeError, "Topic is already merged") if is_merged?
      time = Time.now
      transaction do
        posts.find_each do |post|
          post.topic = topic
          post.original_topic = self
          post.merged_at = time
          post.is_merging = true
          post.save!
          post.save_version("merge", { old_topic_id: id, old_topic_title: title, new_topic_id: topic.id, new_topic_title: topic.title })
        end
        self.merge_target = topic
        self.merged_at = time
        self.is_hidden = true
        self.is_merging = true
        self.updater = user
        save!
        ModAction.log!(user, :forum_topic_merge, self, forum_topic_title: title, user_id: creator_id, new_topic_id: topic.id, new_topic_title: topic.title)
      end
    end

    def undo_merge!(user)
      raise(MergeError, "Topic is not merged") unless is_merged?
      raise(MergeError, "Merge target does not exist") unless ForumTopic.exists?(id: merge_target_id)

      transaction do
        merge_target.posts.where(original_topic: self).find_each do |post|
          post.topic = self
          post.original_topic = nil
          post.merged_at = nil
          post.is_merging = true
          post.save!
          post.save_version("unmerge", { old_topic_id: merge_target.id, old_topic_title: merge_target.title, new_topic_id: id, new_topic_title: title })
        end
        target = merge_target
        self.merge_target = nil
        self.merged_at = nil
        self.is_hidden = false
        self.is_merging = true
        self.updater = user
        save!
        ModAction.log!(user, :forum_topic_unmerge, self, forum_topic_title: title, user_id: creator_id, old_topic_id: target.id, old_topic_title: target.title)
      end
    end

    def is_merged?
      merge_target_id.present?
    end
  end

  include(LogMethods)
  include(CategoryMethods)
  include(VisitMethods)
  include(SubscriptionMethods)
  include(MuteMethods)
  include(MergeMethods)
  extend(SearchMethods)

  def editable_by?(user)
    return true if user.is_admin?
    return false unless visible?(user) && original_post&.editable_by?(user)
    creator_id == user.id
  end

  def can_reply?(user)
    user.level >= category.can_create
  end

  def can_hide?(user)
    return true if user.is_moderator?
    return false if original_post&.is_aibur?
    user.id == creator_id
  end

  def can_delete?(user)
    user.is_admin?
  end

  def initialize_is_hidden
    self.is_hidden = false if is_hidden.nil?
  end

  def initialize_original_post_creator
    return if original_post.blank?
    original_post.creator ||= creator
  end

  def set_posts_destroyer
    return if posts.blank? || destroyer.blank?
    posts.each { |post| post.destroyer = destroyer }
  end

  def last_page
    (response_count / FemboyFans.config.records_per_page.to_f).ceil
  end

  def hide!(user)
    update(is_hidden: true, updater: user)
    ModAction.without_logging { original_post&.hide!(user) }
  end

  def unhide!(user)
    update(is_hidden: false, updater: user)
    ModAction.without_logging { original_post&.unhide!(user) }
  end

  def update_original_post
    original_post&.update_columns(updater_id: updater_id, updater_ip_addr: updater_ip_addr, updated_at: Time.now)
  end

  def is_stale?
    return false unless FemboyFans.config.enable_stale_forum_topics?
    return false if !posts.many? || (original_post&.is_aibur? && (original_post&.tag_change_request&.is_pending? || posts.last.created_at < FemboyFans.config.forum_topic_aibur_stale_window.ago))
    posts.last.created_at < FemboyFans.config.forum_topic_stale_window.ago
  end

  def is_stale_for?(user)
    return false if user.is_moderator?
    is_stale?
  end

  # rubocop:disable Local/CurrentUserOutsideOfRequests -- Used exclusively within requests for json
  def is_read?
    return true if CurrentUser.user.is_anonymous?
    return true if new_record?

    read_by?(CurrentUser.user)
  end
  # rubocop:enable Local/CurrentUserOutsideOfRequests

  def self.available_includes
    %i[category creator updater original_post]
  end

  def visible?(user)
    category && user.level >= category.can_view && (user.is_moderator? || !is_hidden || creator_id == user.id)
  end
end
