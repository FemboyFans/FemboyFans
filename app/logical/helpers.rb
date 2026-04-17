# frozen_string_literal: true

module Helpers
  TARGET = ApplicationController.helpers

  def self.method_missing(name, *, &)
    TARGET.send(name, *, &)
  end
end
