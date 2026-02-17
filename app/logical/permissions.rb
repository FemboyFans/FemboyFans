# frozen_string_literal: true

module Permissions
  module_function

  mattr_accessor(:names, default: {})

  IGNORED_CONTROLLERS = %w[
    admin/dashboards admin/exceptions admin/danger_zone
    moderator/dashboards moderator/ip_addrs moderator/user_text_versions
    users/email_notifications users/password_resets users/passwords users/login_reminders users/deletions users/email_changes
    static application sessions emails api_documentation
  ].freeze
  IGNORED_ACTIONS = %w[new edit search diff show_or_new custom_style edit_user edit_blacklist request_password_reset].freeze
  IGNORED_ROUTES = %w[users:create users:destroy users:home posts:favorites popular:index users:upload_limit].freeze
  PLURAL_ACTIONS = %w[index reorder].freeze

  def action(value)
    I18n.translate!("permissions.actions.#{value}") rescue nil # rubocop:disable Style/RescueModifier
  end

  def controller(value)
    I18n.translate!("permissions.controllers.#{value}") rescue nil # rubocop:disable Style/RescueModifier
  end

  def controller_action(controller, action)
    I18n.translate!("permissions.routes.#{controller}:#{action}") rescue nil # rubocop:disable Style/RescueModifier
  end

  def routes
    @routes ||= Rails.application.routes.routes.select do |route|
      controller = route.defaults[:controller]
      action = route.defaults[:action]
      next false unless controller.present? && !route.internal
      next false if IGNORED_CONTROLLERS.include?(controller) || IGNORED_ACTIONS.include?(action) || IGNORED_ROUTES.include?("#{controller}:#{action}")
      true
    end
  end

  def list
    routes.map do |route|
      "#{route.defaults[:controller]}:#{route.defaults[:action]}"
    end.uniq.sort
  end

  def pretty_list
    list.map { |perm| Permissions.route(perm) }
  end

  def for_select
    list.map { |perm| ["[#{perm}] #{Permissions.route(perm)}", perm] }
  end

  def group(permissions)
    permissions.group_by { |r| r.split(":")[0] }
  end

  def actions
    @actions ||= routes.map { |r| "#{r.defaults[:controller]}:#{r.defaults[:action]}" }.freeze
  end

  def groups
    @groups ||= group(actions).freeze
  end

  def mapping
    @mapping ||= routes.map do |route|
      controller = route.defaults[:controller]
      action = route.defaults[:action]
      {
        controller => {
          "name" => self.controller(controller) || controller.sub("/", ": ").gsub("/", " ").titlecase.singularize.sub(":", ": %s"),
          action => self.action(action) || action.titlecase,
        },
      }
    end.reduce(&:deep_merge).with_open_access.freeze
  end

  def controller_name(controller, plural: false)
    cname = I18n.translate!("permissions.controllers.#{controller}") rescue nil # rubocop:disable Style/RescueModifier
    cname ||= mapping[controller]&.[]("name")
    cname ||= controller.titleize.singularize
    if plural
      parts = cname.split
      last = parts.pop
      cname = "#{parts.join(' ')} #{last.pluralize}"
    end
    cname
  end

  def name(controller, action)
    controller = controller.to_s
    action = action.to_s
    return names["#{controller}:#{action}"] if names["#{controller}:#{action}"].present?
    name = controller_action(controller, action)
    return name if name
    cname = controller_name(controller, plural: PLURAL_ACTIONS.include?(action))
    aname = I18n.translate!("permissions.actions.#{action}") rescue nil # rubocop:disable Style/RescueModifier
    aname ||= mapping[controller]&.[](action) || action.titleize
    return cname.sub("%s", aname) if cname.include?("%s")
    return aname.sub("%s", cname) if aname.include?("%s")
    names["#{controller}:#{action}"] = "#{aname} #{cname}"
  end

  def parse(value)
    return [actions, []] if value.blank? || value == %w[all]
    permissions = []
    invalid = []
    value.each do |permission|
      next permissions += [permission] if groups.include?(permission)
      if permission.ends_with?(":all")
        group = groups[permission[0..-5]]
        next permissions += group if group
      end
      invalid += [permission]
    end
    [permissions, invalid]
  end

  def route(value)
    name(*value.split(":"))
  end
end
