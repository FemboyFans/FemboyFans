# frozen_string_literal: true

class NotificationsController < ApplicationController
  respond_to(:html, :json)

  def index
    @notifications = authorize(Notification).for_user(CurrentUser.user.id).search(search_params(Notification)).paginate(params[:page], limit: params[:limit])
    if params[:r].present?
      notification = Notification.find_by(id: params[:r])
      authorize(notification).update!(is_read: true) if notification.present?
    end
    respond_with(@notifications)
  end

  def show
    @notification = authorize(Notification.find(params[:id]))
    respond_with(@notification) do |format|
      format.html do
        @notification.update!(is_read: true)
        redirect_to(@notification.view_link)
      end
    end
  end

  def destroy
    @notification = authorize(Notification.find(params[:id]))
    @notification.destroy
    notice("Notification deleted")
    respond_with(@notification) do |format|
      format.html { redirect_to(notifications_path) }
    end
  end

  def mark_as_read
    @notification = authorize(Notification.find(params[:id]))
    @notification.mark_as_read!
    notice("Notification marked as read")
    respond_with(@notification) do |format|
      format.html { redirect_to(notifications_path) }
    end
  end

  def mark_all_as_read
    authorize(Notification).for_user(CurrentUser.user.id).update_all(is_read: true)
    CurrentUser.user.update!(unread_notification_count: 0, unread_dmail_count: 0)
    notice("Marked all notifications as read")
    respond_to do |format|
      format.html { redirect_to(notifications_path) }
      format.json
    end
  end
end
