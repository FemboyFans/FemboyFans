# frozen_string_literal: true

class UserBlock < ApplicationRecord
  belongs_to(:user)
  belongs_to(:target, class_name: "User")
  validates(:target_id, uniqueness: { scope: :user_id })
  validate(:validate_staff_user_not_blocking_messages)
  validate(:validate_target_valid)

  def target_name=(value)
    self.target_id = User.name_to_id(value)
  end

  def target_name
    if association(:target).loaded?
      return target&.name || "Anonymous"
    end
    User.id_to_name(target_id)
  end

  def validate_target_valid
    return if target_id.blank?
    if target_id == user_id
      errors.add(:base, "You cannot block yourself")
      throw(:abort)
    end

    if target.is_staff? && disable_messages?
      errors.add(:base, "You cannot block messages from staff members")
      throw(:abort)
    end
  end

  def validate_staff_user_not_blocking_messages
    if user.is_staff? && disable_messages?
      errors.add(:base, "You cannot block messages")
      throw(:abort)
    end
  end

  def self.available_includes
    %i[target user]
  end

  def visible?(user = CurrentUser.user)
    user.is_admin? || user_id == user.id
  end
end
