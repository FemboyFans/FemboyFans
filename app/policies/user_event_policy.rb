# frozen_string_literal: true

class UserEventPolicy < ApplicationPolicy
  def index?
    unbanned?
  end

  def permitted_search_params
    attr = super + %i[category user_id user_name user_ip_addr user_agent]
    attr += %i[session_id] if user.is_admin?
    attr
  end

  def visible_for_search(relation)
    q = super
    return q if user.is_admin?
    q.for_user(user)
  end
end
