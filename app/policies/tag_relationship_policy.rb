# frozen_string_literal: true

class TagRelationshipPolicy < ApplicationPolicy
  def create?
    # record: TagAliasRequest or TagImplicationRequest
    member?
  end

  def destroy?
    return member? unless record.is_a?(model)
    member? && record.rejectable_by?(user)
  end

  def update?
    return member? unless record.is_a?(model)
    member? && record.editable_by?(user)
  end

  def approve?
    return member? && user.can_manage_aibur? unless record.is_a?(model)
    member? && record.approvable_by?(user)
  end

  def api_attributes
    super - %i[undo_data]
  end

  def permitted_attributes
    %i[antecedent_name consequent_name]
  end

  def permitted_attributes_for_create
    params = super + %i[reason forum_topic_id]
    params += %i[skip_forum] if user.is_admin?
    params
  end

  def permitted_search_params
    params = super + %i[name_matches antecedent_name consequent_name status antecedent_tag_category consequent_tag_category creator_id creator_name updater_id updater_name approver_id approver_name] + nested_search_params(creator: User, approver: User)
    params += %i[ip_addr updater_ip_addr] if can_search_ip_addr?
    params
  end

  def model
    TagRelationship
  end
end
