# frozen_string_literal: true

module TextHelper
  def text_diff(this, that)
    Diffy::Diff.new(this, that, ignore_crlf: true).to_s(:html).html_safe
  end

  def hint(text)
    tag.span(text, class: "hint")
  end
end
