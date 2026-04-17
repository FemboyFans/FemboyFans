# frozen_string_literal: true

module Admin
  class ApplicationLogPolicy < ApplicationPolicy
    def index?
      user.is_owner?
    end
  end
end
