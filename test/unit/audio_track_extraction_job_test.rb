# frozen_string_literal: true

require("test_helper")

class AudioTrackExtractionJobTest < ActiveSupport::TestCase
  setup do
    @user = create(:user, created_at: 2.weeks.ago)
  end

  def upload_with_audio
    create(:upload, uploader: @user, tag_string: "tagme", file: fixture_file_upload("test-300x300-with-audio.mp4"), upload_media_asset: build(:upload_media_asset, checksum: nil, creator: @user))
  end

  context("AudioTrackExtractionJob") do
    should("extract the default audio track for a video with audio") do
      upload = upload_with_audio
      AudioTrackExtractionJob.perform_now(upload.upload_media_asset_id)
      track = upload.post.audio_tracks.first

      assert_not_nil(track)
      assert(track.is_default)
      assert_equal("approved", track.status)
      assert_equal("Original", track.label)
      assert_equal("m4a", track.media_asset.file_ext)
    end

    should("not create a track for a silent video") do
      upload = create(:mp4_upload, uploader: @user, tag_string: "tagme")
      AudioTrackExtractionJob.perform_now(upload.upload_media_asset_id)

      assert_equal(0, upload.post.audio_tracks.count)
    end

    should("be idempotent - running twice doesn't create a second default track") do
      upload = upload_with_audio
      AudioTrackExtractionJob.perform_now(upload.upload_media_asset_id)
      AudioTrackExtractionJob.perform_now(upload.upload_media_asset_id)

      assert_equal(1, upload.post.audio_tracks.count)
    end

    should("reuse an orphaned media asset left by a previously-interrupted run instead of failing") do
      upload = upload_with_audio
      AudioTrackExtractionJob.perform_now(upload.upload_media_asset_id)
      orphan_asset_id = upload.post.audio_tracks.first.audio_track_media_asset_id
      # .delete (not .destroy) skips callbacks - no post_event log, no file expunge - so the
      # media asset is left exactly like an interrupted run would leave it: stored, trackless.
      upload.post.audio_tracks.first.delete

      AudioTrackExtractionJob.perform_now(upload.upload_media_asset_id)
      track = upload.post.audio_tracks.first

      assert_not_nil(track)
      assert_equal(orphan_asset_id, track.audio_track_media_asset_id)
      assert_equal(1, AudioTrackMediaAsset.count)
    end

    should("not leave an orphaned media asset behind when creating the AudioTrack fails") do
      upload = upload_with_audio
      AudioTrack.stubs(:create!).raises(ActiveRecord::RecordInvalid.new(AudioTrack.new))

      AudioTrackExtractionJob.perform_now(upload.upload_media_asset_id)

      assert_equal(0, AudioTrackMediaAsset.count)
      assert_equal(0, upload.post.audio_tracks.count)
    end
  end
end
