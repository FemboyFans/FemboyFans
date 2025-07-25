# frozen_string_literal: true

class DmailFilter < ApplicationRecord
  belongs_to_user(:user)
  validates(:words, length: { maximum: 1000 })

  def filtered?(dmail)
    !dmail.from.is_moderator? && has_filter? && (dmail.body =~ regexp || dmail.title =~ regexp || dmail.from.name =~ regexp)
  end

  def has_filter?
    !words.strip.empty?
  end

  def regexp
    @regexp ||= begin
      union = words.split(/[[:space:]]+/).map { |word| Regexp.escape(word) }.join("|")
      /\b#{union}\b/i
    end
  end

  def self.available_includes
    %i[user]
  end
end
