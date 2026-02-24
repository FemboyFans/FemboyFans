# frozen_string_literal: true

class OpenHash < ActiveSupport::HashWithIndifferentAccess
  def respond_to_missing?(name, include_private = false)
    name = name.to_s
    key?(name) || name.end_with?("=") || super
  end

  def method_missing(name, *args)
    name = name.to_s
    if name.end_with?("=")
      public_send(:[]=, name.chomp("="), args.first)
    elsif key?(name)
      public_send(:[], name)
    else
      super
    end
  end

  def self.from(hash = nil, recursive: true, **kwargs)
    hash = kwargs if hash.nil? && kwargs.any?
    raise(ArgumentError, "no hash provided") if hash.nil?
    oh = OpenHash.new
    hash.each do |key, value|
      if recursive && value.is_a?(Hash)
        oh[key] = OpenHash.from(value, recursive: recursive)
      elsif recursive && value.is_a?(Array)
        oh[key] = value.map { |v| v.is_a?(Hash) ? OpenHash.from(v, recursive: recursive) : v }
      else
        oh[key] = value
      end
    end
    oh
  end
end
