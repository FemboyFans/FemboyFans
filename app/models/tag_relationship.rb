# frozen_string_literal: true

class TagRelationship < ApplicationRecord
  self.abstract_class = true

  SUPPORT_HARD_CODED = true

  belongs_to(:forum_post, optional: true)
  belongs_to(:forum_topic, optional: true)
  belongs_to(:antecedent_tag, class_name: "Tag", foreign_key: "antecedent_name", primary_key: "name", default: -> { Tag.find_or_create_by_name(antecedent_name, user: creator) })
  belongs_to(:consequent_tag, class_name: "Tag", foreign_key: "consequent_name", primary_key: "name", default: -> { Tag.find_or_create_by_name(consequent_name, user: creator) })

  scope(:active, -> { approved })
  scope(:approved, -> { where(status: %w[active processing queued]) })
  scope(:deleted, -> { where(status: "deleted") })
  scope(:not_deleted, -> { where.not(status: "deleted") })
  scope(:pending, -> { where(status: "pending") })
  scope(:retired, -> { where(status: "retired") })
  scope(:duplicate_relevant, -> { where(status: %w[active processing queued pending]) })
  scope(:errored, -> { where_ilike(:status, "error: *") })

  before_validation(:normalize_names)
  validates(:status, format: { with: /\A(active|deleted|pending|processing|queued|retired|error: .*)\Z/ })
  validates(:creator_id, :antecedent_name, :consequent_name, presence: true)
  validates(:creator, presence: { message: "must exist" }, if: -> { creator_id.present? })
  validates(:approver, presence: { message: "must exist" }, if: -> { approver_id.present? })
  validates(:forum_topic, presence: { message: "must exist" }, if: -> { forum_topic_id.present? })
  validate(:validate_creator_is_not_limited, on: :create)
  validates(:antecedent_name, tag_name: { disable_ascii_check: true }, if: :antecedent_name_changed?)
  validates(:consequent_name, tag_name: true, if: :consequent_name_changed?)
  validate(:antecedent_and_consequent_are_different)

  def normalize_names
    self.antecedent_name = antecedent_name.downcase.tr(" ", "_")
    self.consequent_name = consequent_name.downcase.tr(" ", "_")
  end

  def validate_creator_is_not_limited
    allowed = creator.can_suggest_tag_with_reason
    if allowed != true
      errors.add(:creator, User.throttle_reason(allowed))
      return false
    end
    true
  end

  def is_approved?
    status.in?(%w[active processing queued])
  end

  def is_retired?
    status == "retired"
  end

  def is_deleted?
    status == "deleted"
  end

  def is_pending?
    status == "pending"
  end

  def is_active?
    status == "active"
  end

  def is_errored?
    status =~ /\Aerror:/
  end

  def approvable_by?(user)
    return false unless is_pending? && user.can_manage_aibur?
    return false unless user.is_owner? || !(consequent_tag&.artist&.is_dnp? || antecedent_tag&.artist&.is_dnp?)
    return false unless user.is_admin? || creator_id != user.id
    FemboyFans.config.tag_change_request_update_limit(user) >= estimate_update_count
  end

  def rejectable_by?(user)
    return true if !is_deleted? && user.can_manage_aibur?
    is_pending? && creator_id == user.id
  end

  def editable_by?(user)
    is_pending? && user.can_manage_aibur?
  end

  module SearchMethods
    def name_matches(name)
      where("(antecedent_name like ? escape E'\\\\' or consequent_name like ? escape E'\\\\')", name.downcase.to_escaped_for_sql_like, name.downcase.to_escaped_for_sql_like)
    end

    def status_matches(status)
      status = status.downcase

      if status == "approved"
        where(status: %w[active processing queued])
      else
        where(status: status)
      end
    end

    def for_creator(id)
      where("creator_id = ?", id)
    end

    def pending_first
      # unknown statuses return null and are sorted first
      order(Arel.sql("array_position(array['queued', 'processing', 'pending', 'active', 'deleted', 'retired'], status::text) NULLS FIRST, #{table_name}.id desc"))
    end

    # FIXME: Rails assigns different join aliases for joins(:antecedent_tag) and joins(:antecedent_tag, :consquent_tag)
    # This makes it impossible to use when ordering, at least from what I can tell.
    # There must be a different solution for this.
    def join_antecedent
      joins("LEFT OUTER JOIN tags antecedent_tag on antecedent_tag.name = antecedent_name")
    end

    def join_consequent
      joins("LEFT OUTER JOIN tags consequent_tag on consequent_tag.name = consequent_name")
    end

    def default_order
      pending_first
    end

    def search(params, user)
      q = super

      if params[:name_matches].present?
        q = q.name_matches(params[:name_matches])
      end

      if params[:antecedent_name].present?
        # Split at both space and , to preserve backwards compatibility
        q = q.where(antecedent_name: params[:antecedent_name].split(/[ ,]/).first(100))
      end

      if params[:consequent_name].present?
        q = q.where(consequent_name: params[:consequent_name].split(/[ ,]/).first(100))
      end

      if params[:status].present?
        q = q.status_matches(params[:status])
      end

      if params[:antecedent_tag_category].present?
        q = q.join_antecedent.where("antecedent_tag.category": params[:antecedent_tag_category].split(",").first(100))
      end

      if params[:consequent_tag_category].present?
        q = q.join_consequent.where("consequent_tag.category": params[:consequent_tag_category].split(",").first(100))
      end

      q = q.where_user(:creator_id, :creator, params)
      q = q.where_user(:approver_id, :approver, params)

      case params[:order]
      when "created_at"
        q = q.order("#{table_name}.created_at desc nulls last, #{table_name}.id desc")
      when "updated_at"
        q = q.order("#{table_name}.updated_at desc nulls last, #{table_name}.id desc")
      when "name"
        q = q.order("antecedent_name asc, consequent_name asc")
      when "tag_count"
        q = q.join_consequent.order("consequent_tag.post_count desc, antecedent_name asc, consequent_name asc")
      when "rating_desc"
        q = q.left_joins(:forum_post).order("forum_posts.percentage_score DESC, #{table_name}.id DESC")
      when "rating_asc"
        q = q.left_joins(:forum_post).order("forum_posts.percentage_score ASC, #{table_name}.id DESC")
      when "score_desc"
        q = q.left_joins(:forum_post).order("forum_posts.total_score DESC, #{table_name}.id DESC")
      when "score_asc"
        q = q.left_joins(:forum_post).order("forum_posts.total_score ASC, #{table_name}.id DESC")
      else
        q = q.apply_basic_order(params)
      end

      q
    end
  end

  module MessageMethods
    def relationship
      # "TagAlias" -> "tag alias", "TagImplication" -> "tag implication"
      self.class.name.underscore.tr("_", " ")
    end

    def approval_message(approver)
      "The #{relationship} [[#{antecedent_name}]] -> [[#{consequent_name}]] #{forum_link} has been approved by @#{approver.name}."
    end

    def failure_message(error = nil)
      "The #{relationship} [[#{antecedent_name}]] -> [[#{consequent_name}]] #{forum_link} failed during processing. Reason: #{error}"
    end

    def reject_message(rejector)
      "The #{relationship} [[#{antecedent_name}]] -> [[#{consequent_name}]] #{forum_link} has been rejected by @#{rejector.name}."
    end

    def retirement_message
      "The #{relationship} [[#{antecedent_name}]] -> [[#{consequent_name}]] #{forum_link} has been retired."
    end

    def forum_link
      "(forum ##{forum_post.id})" if forum_post.present?
    end
  end

  concerning(:EmbeddedText) do
    class_methods do
      def embedded_pattern
        raise(NotImplementedError)
      end
    end
  end

  def antecedent_and_consequent_are_different
    if antecedent_name == consequent_name
      if is_a?(TagAlias)
        errors.add(:base, "Cannot alias a tag to itself")
      elsif is_a?(TagImplication)
        errors.add(:base, "Cannot implicate a tag to itself")
      else
        errors.add(:base, "Antecedent and consequent tags must be different")
      end
    end
  end

  def estimate_update_count
    Post.system_count(antecedent_name, enable_safe_mode: false, include_deleted: true)
  end

  def update_posts(user = User.system)
    Post.without_timeout do
      Post.sql_raw_tag_match(antecedent_name).find_each do |post|
        post.with_lock do
          post.automated_edit = true
          post.updater = user
          post.tag_string += " "
          post.save!
        end
      end
    end
  end

  extend(SearchMethods)
  include(MessageMethods)

  def self.available_includes
    %i[antecedent_tag approver consequent_tag creator forum_post forum_topic]
  end
end
