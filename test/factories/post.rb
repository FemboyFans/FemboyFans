# frozen_string_literal: true

FactoryBot.define do
  factory(:post) do
    uploader { association(:user, created_at: 2.weeks.ago) }
    tag_string { "tag1 tag2" }
    tag_count { 2 }
    tag_count_general { 2 }
    # example.com is used for hostname and would result in bad_source added to all posts
    sequence(:source) { |n| "https://example.net/#{n}" }
    media_asset { create(:random_upload_media_asset, creator: uploader) }

    factory(:webm_post) do
      media_asset { create(:webm_upload_media_asset, :active, creator: uploader) }
    end

    factory(:mp4_post) do
      media_asset { create(:mp4_upload_media_asset, :active, creator: uploader) }
    end

    factory(:jpg_post) do
      media_asset { create(:jpg_upload_media_asset, :active, creator: uploader) }
    end

    factory(:jpg_invalid_post) do
      media_asset { create(:jpg_invalid_upload_media_asset, :active, creator: uploader) }
    end

    factory(:gif_post) do
      media_asset { create(:gif_upload_media_asset, :active, creator: uploader) }
    end

    factory(:png_post) do
      media_asset { create(:png_upload_media_asset, :active, creator: uploader) }
    end

    factory(:apng_post) do
      media_asset { create(:apng_upload_media_asset, :active, creator: uploader) }
    end
  end
end
