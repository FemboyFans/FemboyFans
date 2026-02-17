class OpenHash < ActiveSupport::HashWithIndifferentAccess
  def respond_to_missing?(name, include_private = false)
    name = name.to_s
    key?(name) || name.end_with?("=") || super
  end

  def method_missing(name, *args)
    name = name.to_s
    if name.end_with?("=") && key?(name[..-2])
      public_send(:[]=, name[..-2], args.first)
    elsif key?(name)
      public_send(:[], name)
    else
      super
    end
  end

  def self.from(hash)
    oh = OpenHash.new
    hash.each { |key, value| oh[key] = value }
    oh
  end
end
