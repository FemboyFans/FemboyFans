# frozen_string_literal: true

class CreateAudioTracks < ActiveRecord::Migration[8.1]
  def change
    create_table(:audio_tracks) do |t|
      t.references(:post, foreign_key: true, null: false)
      t.references(:audio_track_media_asset, foreign_key: true, null: false)
      t.references(:creator, foreign_key: { to_table: :users }, null: false)
      t.references(:approver, foreign_key: { to_table: :users }, null: true)
      t.references(:rejector, foreign_key: { to_table: :users }, null: true)
      t.inet(:creator_ip_addr, null: false)
      t.string(:label, null: false)
      t.string(:reason, null: true) # not required for the system-generated default track
      t.string(:rejection_reason, null: true)
      t.boolean(:is_default, null: false, default: false)
      t.integer(:sequence_number, null: false)
      # Which of the post's (possibly several, across replacements) files this track was
      # extracted/suggested against - see AudioTrack#fill_file_md5. A track only actually applies
      # while posts.md5 still matches this; a reverted replacement makes an old track apply again
      # automatically, with no separate "disable"/"restore" bookkeeping needed.
      t.string(:file_md5, limit: 32, null: false)
      # "uploading" until the chunked file upload finishes - see AudioTrackMediaAsset#update_audio_track,
      # which flips this to "pending" once the media asset finalizes. System-created tracks (the
      # auto-extracted default) skip straight to "approved" instead.
      t.string(:status, default: "uploading", null: false)
      t.timestamps
    end
    add_index(:audio_tracks, %i[post_id sequence_number], unique: true)
    add_index(:audio_tracks, %i[post_id file_md5])
    add_index(:audio_tracks, %i[post_id file_md5], unique: true, where: "is_default = true AND status = 'approved'", name: "index_audio_tracks_on_post_id_file_md5_default_approved")
  end
end
