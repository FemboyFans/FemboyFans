# frozen_string_literal: true

class UserNameChangeRequest < ApplicationRecord
  validates(:original_name, :desired_name, presence: true)
  validates(:change_reason, length: { maximum: 250 })
  validate(:not_limited, on: :create)
  validates(:desired_name, user_name: true)
  before_validation(:set_original_name)
  belongs_to_user(:user, clones: :creator)
  belongs_to_user(:creator, ip: true)
  belongs_to_user(:approver, optional: true)
  enum(:status, %w[pending approved rejected].index_with(&:to_s))
  attr_accessor(:skip_limited_validation)

  def set_original_name
    self.original_name = user&.name
  end

  def self.search(params, user)
    q = super

    q = q.where_user(:user_id, :current, params)

    if params[:original_name].present?
      q = q.where_ilike(:original_name, User.normalize_name(params[:original_name]))
    end

    if params[:desired_name].present?
      q = q.where_ilike(:desired_name, User.normalize_name(params[:desired_name]))
    end

    q.apply_basic_order(params)
  end

  def approve!(approver = User.system)
    update(status: "approved", approver: approver)
    user.update(name: desired_name, force_name_change: false)
    body = "Your name change request has been approved. Be sure to log in with your new user name."
    Dmail.create_automated(title: "Name change request approved", body: body, to_id: user_id)
  end

  def not_limited
    return true if skip_limited_validation == true
    if UserNameChangeRequest.exists?(["user_id = ? and created_at >= ?", user_id, 1.week.ago])
      errors.add(:base, "You can only submit one name change request per week")
      false
    else
      true
    end
  end

  def self.available_includes
    %i[approver user]
  end

  def visible?(user)
    user.is_moderator? || user_id == user.id
  end
end
