# frozen_string_literal: true

class AddIsAnimatedWebpToMediaAssets < ActiveRecord::Migration[7.1]
  def change
    add_column_with_value(:upload_media_assets, :is_animated_webp, :boolean, value: false)
    add_column_with_value(:mascot_media_assets, :is_animated_webp, :boolean, value: false)
    add_column_with_value(:post_replacement_media_assets, :is_animated_webp, :boolean, value: false)
  end
end
