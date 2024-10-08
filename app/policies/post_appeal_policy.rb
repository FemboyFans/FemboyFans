# frozen_string_literal: true

class PostAppealPolicy < ApplicationPolicy
  def destroy?
    approver? && (!record.is_a?(PostAppeal) || record.pending?)
  end

  def permitted_search_params
    params = super + %i[reason_matches creator_id creator_name post_id post_tags_match status]
    params += %i[ip_addr] if can_search_ip_addr?
    params
  end

  def permitted_attributes_for_create
    %i[post_id reason]
  end

  def permitted_attributes_for_update
    %i[reason]
  end
end
