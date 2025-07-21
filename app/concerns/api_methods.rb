# frozen_string_literal: true

module ApiMethods
  extend(ActiveSupport::Concern)

  module ClassMethods
    def available_includes
      []
    end

    def multiple_includes
      reflections.select { |_, v| v.macro == :has_many }.keys.map(&:to_sym)
    end

    def associated_models(name)
      if reflections[name].options[:polymorphic]
        reflections[name].active_record.try(:model_types) || []
      else
        [reflections[name].class_name]
      end
    end
  end

  delegate(:available_includes, to: :class)

  # XXX deprecated, shouldn't expose this as an instance method.
  def api_attributes(user)
    policy = Pundit.policy(user, self) || ApplicationPolicy.new(user, self)
    policy.api_attributes
  end

  # XXX deprecated, shouldn't expose this as an instance method.
  def html_data_attributes(user)
    policy = Pundit.policy(user, self) || ApplicationPolicy.new(user, self)
    policy.html_data_attributes
  end

  def process_api_attributes(options, underscore: false)
    options[:methods] ||= []
    attributes, methods = api_attributes(options[:user]).partition { |attr| has_attribute?(attr) }
    methods += options[:methods]
    if underscore && options[:only].blank?
      options[:only] = attributes + methods
    else
      options[:only] ||= attributes + methods
    end

    attributes &= options[:only]
    methods &= options[:only]

    options[:only] = attributes
    options[:methods] = methods

    options.delete(:methods) if options[:methods].empty?
    options
  end

  def serializable_hash(options = {})
    options ||= {}
    options[:user] ||= CurrentUser.user || User.anonymous
    return :not_visible unless visible?(options[:user])
    if options[:only].is_a?(String)
      options.delete(:methods)
      options.delete(:include)
      options.merge!(ParameterBuilder.serial_parameters(options[:only], self, options))
      if options[:only].include?("_")
        options[:only].delete("_")
        options = process_api_attributes(options, underscore: true)
      end
    else
      options = process_api_attributes(options)
    end
    options[:only] += [SecureRandom.hex(6)]

    hash = super
    hash.transform_keys! { |key| key.delete("?").gsub("apionly_", "") }
    deep_reject_hash(hash) { |_, v| v == :not_visible }
  end

  def visible?(_user)
    true
  end

  def deep_reject_hash(hash, &block)
    hash.each_with_object({}) do |(key, value), result|
      if value.is_a?(Hash)
        result[key] = deep_reject_hash(value, &block)
      elsif value.is_a?(Array)
        result[key] = value.map { |v| v.is_a?(Hash) ? deep_reject_hash(v, &block) : v }.reject { |i| block.call(nil, i) }
      elsif !block.call(key, value)
        result[key] = value
      end
    end
  end
end
