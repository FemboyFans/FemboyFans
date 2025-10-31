# frozen_string_literal: true

module Users
  class LoginReminderMailer < ApplicationMailer
    include(UsersHelper)
    default(from: FemboyFans.config.mail_from_addr, content_type: "text/html")

    def notice(user)
      @user = user
      if user.email.present?
        headers["List-Unsubscribe"] = "<#{Routes.users_email_notification_url(user_id: @user.id, sig: email_sig(@user, :unsubscribe), host: FemboyFans.config.hostname, only_path: false)}>"
        mail(to: user.email, subject: "#{FemboyFans.config.app_name} login reminder")
      end
    end
  end
end
