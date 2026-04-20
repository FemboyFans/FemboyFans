# frozen_string_literal: true

module Admin
  class RequestLog < ApplicationLog
    def self.path_for(environment = Rails.env)
      Rails.root.join("log", "requests.#{environment}.jsonl")
    end
  end
end
