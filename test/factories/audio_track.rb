# frozen_string_literal: true

FactoryBot.define do
  factory(:audio_track) do
    creator { association(:user, created_at: 2.weeks.ago) }
    sequence(:label) { |n| "audio_track_label#{n}" }
    sequence(:reason) { |n| "audio_track_reason#{n}" }
    audio_track_media_asset { build(:m4a_audio_track_media_asset, creator: creator, creator_ip_addr: creator_ip_addr) }
  end
end
