# frozen_string_literal: true

class UserMailer < ApplicationMailer
  helper(ApplicationHelper)
  helper(UsersHelper)
  default(from: FemboyFans.config.mail_from_addr, content_type: "text/html")

  def dmail_notice(dmail)
    @dmail = dmail
    mail(to: "#{dmail.to.name} <#{dmail.to.email}>", subject: "#{FemboyFans.config.app_name} - Message received from #{dmail.from.name}")
  end

  def forum_notice(user, forum_topic, forum_posts)
    @user = user
    @forum_topic = forum_topic
    @forum_posts = forum_posts
    mail(to: "#{user.name} <#{user.email}>", subject: "#{FemboyFans.config.app_name} forum topic #{forum_topic.title} updated")
  end
end
