# frozen_string_literal: true

class BulkUpdateRequestPolicy < ApplicationPolicy
  def update?
    return member? unless record.is_a?(BulkUpdateRequest)
    member? && record.editable?(user)
  end

  def approve?
    return member? && user.can_manage_aibur? unless record.is_a?(BulkUpdateRequest)
    member? && record.approvable?(user)
  end

  def destroy?
    return member? unless record.is_a?(BulkUpdateRequest)
    member? && record.rejectable?(user)
  end

  alias reject? destroy?

  def permitted_attributes
    %i[script]
  end

  def permitted_attributes_for_create
    attr = super + %i[title reason forum_topic_id]
    attr += %i[skip_forum] if user.is_admin?
    attr
  end

  def permitted_search_params
    super + %i[creator_id creator_name approver_id approver_name forum_topic_id forum_post_id status title_matches script_matches order]
  end
end
