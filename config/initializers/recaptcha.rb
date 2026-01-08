# frozen_string_literal: true

Recaptcha.configure do |config|
  config.site_key   = FemboyFans.config.recaptcha.site_key
  config.secret_key = FemboyFans.config.recaptcha.secret_key
  # config.proxy = "http://example.com"
end
