# frozen_string_literal: true

class AddAudioTrackLimitsToAdminConfig < ActiveRecord::Migration[8.1]
  def change
    add_column(:admin_config, :audio_track_per_day_limit, :integer, default: 2, null: false)
    add_column(:admin_config, :audio_track_per_day_limit_bypass, :integer, default: User::Levels::JANITOR, null: false)
    add_column(:admin_config, :audio_track_per_post_limit, :integer, default: 5, null: false)
    add_column(:admin_config, :audio_track_per_post_limit_bypass, :integer, default: User::Levels::JANITOR, null: false)
  end
end
