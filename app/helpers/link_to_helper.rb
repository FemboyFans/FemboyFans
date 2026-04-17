# frozen_string_literal: true

module LinkToHelper
  def link_to(*, **options)
    ifopt = options.delete(:if)
    unlessopt = options.delete(:unless)
    format = options.delete(:format)
    li = options.delete(:li)
    return "".html_safe if ifopt == false || unlessopt == true
    content = super
    content = format.gsub("%s", content) if format
    content = %(<li>#{content}</li>) if li
    content.html_safe # rubocop:disable Rails/OutputSafety
  end

  def link_to_enclosed(*, char: "()", **)
    link_to(*, format: "#{char[0]}%s#{char[1]}", **)
  end

  def link_to_enclosed_if(condition, *, **)
    if condition
      link_to_enclosed(*, **)
    end
  end

  def li_link_to_if(condition, *, **)
    if condition
      li_link_to(*, **)
    end
  end

  def subnav_link_to_if(condition, *, **)
    if condition
      subnav_link_to(*, **)
    end
  end

  def nav_link_to_if(condition, *, **)
    if condition
      nav_link_to(*, **)
    end
  end
end
