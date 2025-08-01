# frozen_string_literal: true

FactoryBot.define do
  factory(:artist_url) do
    association(:artist)
    sequence(:url) { |n| "artist_domain_#{n}.com" }
  end
end
