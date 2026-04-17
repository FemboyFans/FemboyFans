# frozen_string_literal: true

class ApplicationPresenter
  attr_reader(:h, :r)

  def initialize(helper = nil, view = nil)
    @h = helper || view || Helpers
    @r = Routes
    @view = view
  end

  delegate(:link_to, :tag, :safe_join, to: :h)

  def view
    return @view if @view
    raise(StandardError, "missing view")
  end

  def self.e(string)
    CGI.escapeHTML(string.to_s)
  end

  def self.u(string)
    URI.escape(string)
  end

  def e(string)
    CGI.escapeHTML(string)
  end

  def u(string)
    CGI.escape(string)
  end
end
