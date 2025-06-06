# frozen_string_literal: true

# Load the Rails application.
require_relative("application")

Dotenv.load(Rails.root.join(".env.local"))

# Initialize the Rails application.
Rails.application.initialize!
