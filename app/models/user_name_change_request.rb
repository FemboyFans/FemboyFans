# frozen_string_literal: true

class UserNameChangeRequest < ApplicationRecord
  after_initialize(:initialize_attributes, if: :new_record?)
  validates(:original_name, :desired_name, presence: true)
  validates(:status, inclusion: { in: %w[pending approved rejected] })
  validates(:change_reason, length: { maximum: 250 })
  validate(:not_limited, on: :create)
  validates(:desired_name, user_name: true)
  belongs_to(:user)
  belongs_to(:approver, class_name: "User", optional: true)
  attr_accessor(:skip_limited_validation)

  def initialize_attributes
    self.user_id ||= CurrentUser.user.id
    self.original_name ||= CurrentUser.user.name
  end

  def self.pending
    where(status: "pending")
  end

  def self.approved
    where(status: "approved")
  end

  def self.search(params)
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

  def rejected?
    status == "rejected"
  end

  def approved?
    status == "approved"
  end

  def pending?
    status == "pending"
  end

  def approve!(approver = CurrentUser.user)
    update(status: "approved", approver_id: approver.id)
    user.update(name: desired_name, force_name_change: false)
    body = "Your name change request has been approved. Be sure to log in with your new user name."
    Dmail.create_automated(title: "Name change request approved", body: body, to_id: user_id)
  end

  def not_limited
    return true if skip_limited_validation == true
    if UserNameChangeRequest.exists?(["user_id = ? and created_at >= ?", CurrentUser.user.id, 1.week.ago])
      errors.add(:base, "You can only submit one name change request per week")
      false
    else
      true
    end
  end

  def self.available_includes
    %i[approver user]
  end

  def visible?(user = CurrentUser.user)
    user.is_moderator? || user_id == user.id
  end
end
