# frozen_string_literal: true

class BanPolicy < ApplicationPolicy
  def create?
    user.is_moderator?
  end

  def update?
    user.is_moderator?
  end

  def delete?
    user.is_moderator?
  end

  def undelete?
    user.is_moderator?
  end

  # Permanent, unrecoverable removal - restricted beyond the normal soft-delete.
  def destroy?
    user.is_moderator? && (!record.is_a?(Ban) || record.destroyable_by?(user))
  end

  def permitted_attributes
    %i[reason duration expires_at is_permaban]
  end

  def permitted_attributes_for_create
    super + %i[user_id user_name]
  end

  def permitted_search_params
    params = super + %i[creator_id creator_name user_id user_name reason_matches expired is_deleted include_deleted order] + nested_search_params(creator: User, user: User)
    params << :ip_addr if can_search_ip_addr?
    params
  end

  def api_attributes
    super + %i[expired?]
  end

  def html_data_attributes
    super + %i[expired?]
  end
end
