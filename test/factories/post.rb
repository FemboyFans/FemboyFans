# frozen_string_literal: true

FactoryBot.define do
  factory(:post) do
    sequence(:md5, &:to_s)
    uploader { create(:user, created_at: 2.weeks.ago) }
    uploader_ip_addr { "127.0.0.1" }
    tag_string { "tag1 tag2" }
    tag_count { 2 }
    tag_count_general { 2 }
    file_ext { "jpg" }
    image_width { 1500 }
    image_height { 1000 }
    file_size { 2000 }
    rating { "q" }
    duration { 0.0 }
    generated_samples do
      samples = %w[preview]
      samples += %w[large] if supports_large?
      samples += %w[crop] if is_image?
      samples
    end
    sequence(:source) { |n| "https://example.com/#{n}" }
  end
end
