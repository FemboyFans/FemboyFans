# frozen_string_literal: true

class CreateAudioTrackMediaAssets < ActiveRecord::Migration[8.1]
  def change
    create_table(:audio_track_media_assets) do |t|
      t.references(:creator, foreign_key: { to_table: :users }, null: false)
      t.references(:media_metadata, foreign_key: true, null: false)
      t.inet(:creator_ip_addr, null: false)
      t.string(:checksum, limit: 32, null: true, index: true)
      t.string(:md5, limit: 32, null: true, index: true) # only set when completed, no unique index - the same track can be suggested on multiple posts
      t.string(:file_ext, limit: 4, null: true) # only set when completed
      t.boolean(:is_animated_png, null: true) # rubocop:disable Rails/ThreeStateBooleanColumn -- unused for audio, kept for MediaAsset::FileMethods#set_file_attributes compatibility
      t.boolean(:is_animated_gif, null: true) # rubocop:disable Rails/ThreeStateBooleanColumn -- unused for audio, kept for MediaAsset::FileMethods#set_file_attributes compatibility
      t.boolean(:is_animated_webp, null: true) # rubocop:disable Rails/ThreeStateBooleanColumn -- unused for audio, kept for MediaAsset::FileMethods#set_file_attributes compatibility
      t.integer(:file_size, null: true) # only set when completed
      t.integer(:image_width, null: true) # unused for audio - MediaAsset.requires_dimensions is false for this class
      t.integer(:image_height, null: true) # unused for audio - MediaAsset.requires_dimensions is false for this class
      t.numeric(:duration) # only set when completed
      t.integer(:framecount) # unused for audio, always 0
      t.string(:pixel_hash, limit: 32, null: true, index: true) # unused for audio, always nil
      t.string(:status, default: "pending", null: false)
      t.string(:status_message, null: true)
      t.integer(:last_chunk_id, null: false, default: 0)
      t.timestamps
    end
  end
end
