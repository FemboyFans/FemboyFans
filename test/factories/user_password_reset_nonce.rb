# frozen_string_literal: true

FactoryBot.define do
  factory(:user_password_reset_nonce) do
    association(:user)
  end
end
