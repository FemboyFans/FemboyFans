# frozen_string_literal: true

FactoryBot.define do
  factory(:note) do
    association(:creator, factory: :user)
    association(:post)
    x { 1 }
    y { 1 }
    width { 1 }
    height { 1 }
    is_active { true }
    sequence(:body) { |n| "note_body_#{n}" }
  end
end
