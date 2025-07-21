# frozen_string_literal: true

class ApiKeyPolicy < ApplicationPolicy
  def index?
    unbanned?
  end

  def create?
    unbanned?
  end

  def update?
    unbanned? && (!record.is_a?(ApiKey) || record.user_id == user.id)
  end

  def destroy?
    unbanned? && (!record.is_a?(ApiKey) || record.user_id == user.id)
  end

  def usage?
    unbanned?
  end

  def permitted_attributes
    [:name, :permitted_ip_addresses, { permissions: [] }]
  end

  def permitted_search_params
    super + %i[user_id user_name]
  end

  def api_attributes
    super - %i[key]
  end

  def visible_for_search(relation)
    q = super
    return q if user.is_owner?
    q.for_user(user)
  end
end
