# frozen_string_literal: true

class BanPolicy < ApplicationPolicy
  def create?
    user.is_moderator?
  end

  def update?
    user.is_moderator?
  end

  def destroy?
    user.is_moderator?
  end

  def permitted_attributes
    %i[reason duration expires_at is_permaban]
  end

  def permitted_attributes_for_create
    super + %i[user_id user_name]
  end

  def permitted_search_params
    super + %i[banner_id banner_name user_id user_name reason_matches expired order]
  end

  def api_attributes
    super + %i[expired?]
  end

  def html_data_attributes
    super + %i[expired?]
  end
end
