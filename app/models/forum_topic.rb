# frozen_string_literal: true

class ForumTopic < ApplicationRecord
  belongs_to_creator
  belongs_to_updater
  belongs_to :category, class_name: "ForumCategory"
  has_many :posts, -> { order("forum_posts.id asc") }, class_name: "ForumPost", foreign_key: "topic_id", dependent: :destroy
  has_one :original_post, -> { order("forum_posts.id asc") }, class_name: "ForumPost", foreign_key: "topic_id", inverse_of: :topic
  has_many :statuses, class_name: "ForumTopicStatus"
  before_validation :initialize_is_hidden, on: :create
  validate :category_valid
  validates :title, :creator_id, presence: true
  validates_associated :original_post
  validates :original_post, presence: true
  validates :title, length: { minimum: 1, maximum: 250 }
  validate :category_allows_creation, on: :create
  validate :validate_not_aibur, if: :will_save_change_to_is_hidden?
  accepts_nested_attributes_for :original_post
  after_update :update_original_post
  after_destroy :log_delete
  after_commit :log_save, on: %i[create update]

  attribute :category_id, :integer, default: -> { FemboyFans.config.default_forum_category }

  def validate_not_aibur
    return if CurrentUser.is_moderator? || !original_post&.is_aibur?

    if is_hidden?
      errors.add(:topic, "is for an alias, implication, or bulk update request. It cannot be hidden")
      throw(:abort)
    end
  end

  module CategoryMethods
    extend ActiveSupport::Concern

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
        ModAction.log!(is_hidden? ? :forum_topic_hide : :forum_topic_unhide, self, forum_topic_title: title, user_id: creator_id)
      end

      if saved_change_to_is_locked?
        specific = true
        ModAction.log!(is_locked ? :forum_topic_lock : :forum_topic_unlock, self, forum_topic_title: title, user_id: creator_id)
      end

      if saved_change_to_is_sticky?
        specific = true
        ModAction.log!(is_sticky ? :forum_topic_stick : :forum_topic_unstick, self, forum_topic_title: title, user_id: creator_id)
      end

      if saved_change_to_category_id? && !previously_new_record?
        specific = true
        ModAction.log!(:forum_topic_move, self, forum_topic_title: title, user_id: creator_id, forum_category_id: category_id, forum_category_name: category.name, old_forum_category_id: category_id_before_last_save, old_forum_category_name: ForumCategory.find_by(id: category_id_before_last_save)&.name || "")
      end

      unless specific || previously_new_record?
        ModAction.log!(:forum_topic_update, self, forum_topic_title: title, user_id: creator_id)
      end
    end

    def log_delete
      ModAction.log!(:forum_topic_delete, self, forum_topic_title: title, user_id: creator_id)
    end
  end

  module SearchMethods
    def visible(user)
      q = joins(:category).where("forum_categories.can_view <= ?", user.level)
      q = q.where("forum_topics.is_hidden = FALSE OR forum_topics.creator_id = ?", user.id) unless user.is_moderator?
      q
    end

    def unmuted
      left_outer_joins(:statuses).where("(forum_topic_statuses.mute = ? AND forum_topic_statuses.user_id = ?) OR forum_topic_statuses.id IS NULL", false, CurrentUser.user.id)
    end

    def sticky_first
      order(is_sticky: :desc, last_post_created_at: :desc)
    end

    def default_order
      order(last_post_created_at: :desc)
    end

    def search(params)
      q = super
      q = q.visible(CurrentUser.user)

      q = q.attribute_matches(:title, params[:title_matches])

      if params[:category_id].present?
        q = q.for_category_id(params[:category_id])
      end

      if params[:title].present?
        q = q.where("title = ?", params[:title])
      end

      q = q.attribute_matches(:is_sticky, params[:is_sticky])
      q = q.attribute_matches(:is_locked, params[:is_locked])
      q = q.attribute_matches(:is_hidden, params[:is_hidden])

      case params[:order]
      when "sticky"
        q = q.sticky_first
      when "last_post_created_at"
        q = q.order(last_post_created_at: :desc)
      when "created_at"
        q = q.order(created_at: :desc)
      else
        q = q.apply_basic_order(params)
      end

      q
    end
  end

  module VisitMethods
    def read_by?(user = nil)
      user ||= CurrentUser.user

      return true if user_mute(user)

      if user.last_forum_read_at && updated_at <= user.last_forum_read_at
        return true
      end

      user.has_viewed_thread?(id, updated_at)
    end

    def mark_as_read!(user = CurrentUser.user)
      return if user.is_anonymous?

      match = ForumTopicVisit.where(user_id: user.id, forum_topic_id: id).first
      if match
        match.update_attribute(:last_read_at, updated_at)
      else
        ForumTopicVisit.create(user_id: user.id, forum_topic_id: id, last_read_at: updated_at)
      end

      has_unread_topics = ForumTopic.visible(user).where("forum_topics.updated_at >= ?", user.last_forum_read_at)
                                    .joins("left join forum_topic_visits on (forum_topic_visits.forum_topic_id = forum_topics.id and forum_topic_visits.user_id = #{user.id})")
                                    .where("(forum_topic_visits.id is null or forum_topic_visits.last_read_at < forum_topics.updated_at)")
                                    .exists?
      unless has_unread_topics
        user.update_attribute(:last_forum_read_at, Time.now)
        ForumTopicVisit.prune!(user)
      end
    end
  end

  module SubscriptionMethods
    def user_subscription(user)
      statuses.where(user_id: user.id, subscription: true).first
    end
  end

  module MuteMethods
    def user_mute(user)
      statuses.where(user_id: user.id, mute: true).first
    end
  end

  include LogMethods
  include CategoryMethods
  include VisitMethods
  include SubscriptionMethods
  include MuteMethods
  extend SearchMethods

  def editable_by?(user)
    return true if user.is_admin?
    return false unless visible?(user) && original_post.editable_by?(user)
    creator_id == user.id
  end

  def visible?(user)
    return false unless category && user.level >= category.can_view
    return true if CurrentUser.is_moderator?
    return false if is_hidden && user.id != creator_id
    true
  end

  def can_reply?(user = CurrentUser.user)
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

  def last_page
    (response_count / FemboyFans.config.records_per_page.to_f).ceil
  end

  def hide!
    update(is_hidden: true)
  end

  def unhide!
    update(is_hidden: false)
  end

  def update_original_post
    original_post&.update_columns(updater_id: CurrentUser.id, updated_at: Time.now)
  end

  def is_stale?
    return false if posts.empty? || (original_post&.is_aibur? && (original_post&.tag_change_request&.is_pending? || posts.last.created_at < 1.year.ago))
    posts.last.created_at < 6.months.ago
  end

  def is_stale_for?(user)
    return false if user.is_moderator?
    is_stale?
  end
end
