# frozen_string_literal: true

class ConfigPolicy < ApplicationPolicy
  def show?
    user.is_moderator?
  end

  def update?
    user.is_owner?
  end

  def permitted_attributes_for_update
    Config.settable_columns(user).map(&:name).map(&:to_sym)
  end
end
