# frozen_string_literal: true

module HtmlHelper
  def vote_display(vote)
    sanitize(vote.vote_display, tags: %w[span], attributes: %w[class])
  end
end
