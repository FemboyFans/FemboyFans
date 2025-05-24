# frozen_string_literal: true

source "https://rubygems.org/"

gem "dotenv", require: "dotenv/load"

gem "rails", "~> 7.1.0"
gem "pg"
gem "dalli", platforms: :ruby
gem "simple_form"
gem "ruby-vips"
gem "bcrypt", require: "bcrypt"
gem "draper"
gem "streamio-ffmpeg"
gem "responders"
# gem "dtext_rb", git: "https://github.com/FemboyFans/dtext_rb.git", branch: "master", require: "dtext"
gem "dtext_rb", require: "dtext"
gem "bootsnap"
gem "addressable"
gem "recaptcha", require: "recaptcha/rails"
gem "webpacker", ">= 4.0.x"
gem "retriable"
gem "sidekiq", "~> 7.0"
gem "marcel"
# bookmarks for later, if they are needed
# gem 'sidekiq-worker-killer'
gem "sidekiq-unique-jobs"
gem "sidekiq-failures"
gem "redis"
gem "request_store"

gem "diffy"
gem "rugged"

gem "elasticsearch", "~> 8.18.0"

gem "mailgun-ruby"

gem "faraday"
gem "faraday-follow_redirects"
gem "faraday-retry"

group :production do
  gem "pitchfork"
end

group :development do
  gem "puma"
  gem "debug", require: false
  gem "rubocop", require: false
  gem "rubocop-erb", require: false
  gem "rubocop-rails", require: false
  gem "rexml", ">= 3.3.6"
  gem "ruby-lsp"
  gem "ruby-lsp-rails", "~> 0.3.13"
  gem "faker", require: false
  gem "bullet"
  gem "active_record_query_trace"
end

group :test do
  gem "shoulda-context", require: false
  gem "shoulda-matchers", require: false
  gem "factory_bot_rails", require: false
  gem "mocha", require: false
  gem "webmock", require: false
  gem "simplecov", require: false
  gem "simplecov-cobertura", require: false
end

gem "pundit", "~> 2.3"
gem "net-ftp", "~> 0.3.4"
gem "rakismet", "~> 1.5"
gem "jwt", "~> 2.8"
gem "rotp", "~> 6.3"
gem "rqrcode", "~> 2.2"
gem "click_house", "~> 2.1"
gem "after_commit_everywhere", "~> 1.6"
gem "active_record_extended", "~> 3.3"
# https://github.com/rails/rails/issues/49259, https://github.com/ruby/irb/pull/916#discussion_r1553958795
gem "irb", "~> 1.15.2"

gem "recursive-open-struct", "~> 2.0"
