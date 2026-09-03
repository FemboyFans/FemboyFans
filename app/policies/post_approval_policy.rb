# frozen_string_literal: true

# record: Post
class PostApprovalPolicy < ApplicationPolicy
  def create?
    approver? && (!record.is_a?(Post) || record.uploader_id != user.id || user.is_admin?)
  end

  def destroy?
    approver?
  end

  def permitted_search_params
    params = super + %i[post_id user_id user_name post_tags_match] + nested_search_params(user: User, post: Post)
    params << :ip_addr if can_search_ip_addr?
    params
  end
end
