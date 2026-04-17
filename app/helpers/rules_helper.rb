# frozen_string_literal: true

module RulesHelper
  OPTIONS = { allow_color: true, disable_mentions: true, max_thumbs: 0 }.freeze

  def managable?
    CurrentUser.user.is_admin? && request.format.html?
  end

  def format_rules_toc(categories)
    html = ""
    categories.each do |category|
      html += "[b]#{category.order}. [[##{category.anchor}|#{category.name}]][/b]\n"
      html += format_category_rules_toc(category)
      html += "\n\n"
    end
    format_text(html, **OPTIONS)
  end

  def format_category_rules_toc(category)
    rules = category.rules.map do |rule|
      "#{category.order}.#{rule.order} [[##{rule.anchor}|#{rule.name}]]"
    end
    rules.join("\n")
  end

  def format_rules_body(wiki)
    format_text(wiki.try(:body) || "", **OPTIONS)
  end

  def format_rules_content(categories)
    html = categories.map do |category|
      format_category(category)
    end
    html = format_text(html.join("\n\n"), **OPTIONS)
    categories.each do |category|
      html = html.gsub("delete_rule_category_#{category.id}_link", link_to("delete", rule_category_path(category), method: :delete, data: { confirm: "Are you sure you want to delete this rule category? This cannot be undone." }))
      category.rules.each do |rule|
        html = html.gsub("delete_rule_#{rule.id}_link", link_to("delete", rule_path(rule), method: :delete, data: { confirm: "Are you sure you want to delete this rule? This cannot be undone." }))
      end
    end
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def format_category(category)
    link = " [sup](\"edit\":#{edit_rule_category_path(category)})[/sup] [sup](delete_rule_category_#{category.id}_link)[/sup]"
    "h2. #{category.order} #{category.name}#{link if managable?}\n\n#{format_category_rules(category)}\n\n"
  end

  def format_category_rules(category)
    category.rules.map do |rule|
      format_rule(rule)
    end.join("\n\n")
  end

  def format_rule(rule)
    link = "[sup](\"edit\":#{edit_rule_path(rule)})[/sup] [sup](delete_rule_#{rule.id}_link)[/sup]"
    "[quote]h3. #{rule.category.order}.#{rule.order} #{rule.name} [##{rule.anchor}]#{link if managable?}\n\n#{rule.description}[/quote]"
  end
end
