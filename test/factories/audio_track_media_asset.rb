# frozen_string_literal: true

FactoryBot.define do
  factory(:audio_track_media_asset) do
    creator { association(:user, created_at: 2.weeks.ago) }
    checksum { SecureRandom.hex(16) }

    factory(:m4a_audio_track_media_asset) do
      sequence(:checksum) { |n| Digest::MD5.hexdigest("m4a_audio_track_media_asset#{n}") }
      md5 { checksum }
      file_ext { "m4a" }
      is_animated_png { false }
      is_animated_gif { false }
      is_animated_webp { false }
      file_size { 128.kilobytes }
      duration { 5.7 }
      framecount { 0 }
      status { "active" }
      skip_files { true }
    end
  end
end
