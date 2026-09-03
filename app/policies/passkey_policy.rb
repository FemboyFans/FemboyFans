# frozen_string_literal: true

class PasskeyPolicy < ApplicationPolicy
  def index?
    member?
  end

  def create?
    member?
  end

  def destroy?
    return unbanned? unless record.is_a?(Passkey)
    unbanned? && record.user_id == user.id
  end
end
