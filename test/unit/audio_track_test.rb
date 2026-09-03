# frozen_string_literal: true

require("test_helper")

class AudioTrackTest < ActiveSupport::TestCase
  setup do
    @user = create(:user, created_at: 2.weeks.ago)
    @mod_user = create(:moderator_user, created_at: 2.weeks.ago)
    # mp4_post's media asset factory has duration 5.7, matching the m4a_audio_track_media_asset
    # factory's duration below - so a plain attributes_for(:audio_track) track always satisfies
    # the "within 1 second of the post" check without every unrelated test having to think about it.
    @post = create(:mp4_post, uploader: @mod_user)
  end

  context("User Limits:") do
    should("fail on too many per post in one day") do
      AdminConfig.any_instance.stubs(:audio_track_per_day_limit).returns(-1)
      @track = @post.audio_tracks.create(attributes_for(:audio_track).merge(creator: @user))

      assert_equal(["Creator has already suggested too many audio tracks for this post today"], @track.errors.full_messages)
    end

    should("fail on too many per post total") do
      AdminConfig.any_instance.stubs(:audio_track_per_post_limit).returns(-1)
      @track = @post.audio_tracks.create(attributes_for(:audio_track).merge(creator: @user))

      assert_equal(["Creator already has too many pending audio track suggestions for this post"], @track.errors.full_messages)
    end

    should("not rate limit or require a reason for a system-generated track") do
      AdminConfig.any_instance.stubs(:audio_track_per_day_limit).returns(-1)
      @track = @post.audio_tracks.create(attributes_for(:audio_track).merge(creator: @user, reason: nil, is_system_generated: true))

      assert_equal(0, @track.errors.size)
    end
  end

  context("Creation:") do
    should("assign sequential sequence numbers per post") do
      @first = @post.audio_tracks.create!(attributes_for(:audio_track).merge(creator: @user))
      @second = @post.audio_tracks.create!(attributes_for(:audio_track).merge(creator: @user))

      assert_equal(1, @first.sequence_number)
      assert_equal(2, @second.sequence_number)
    end

    should("start pending and require a label and reason") do
      @track = @post.audio_tracks.create(attributes_for(:audio_track).merge(creator: @user, label: "", reason: ""))

      assert_includes(@track.errors.full_messages, "Label can't be blank")
      assert_includes(@track.errors.full_messages, "Reason can't be blank")
    end

    should("refuse tracks for a post that isn't a video") do
      image_post = create(:jpg_post, uploader: @mod_user)
      @track = image_post.audio_tracks.create(attributes_for(:audio_track).merge(creator: @user))

      assert_includes(@track.errors.full_messages, "Post is not a video")
    end

    should("refuse a track that runs more than a second past the post's duration") do
      @track = @post.audio_tracks.create(attributes_for(:audio_track).merge(creator: @user, audio_track_media_asset: build(:m4a_audio_track_media_asset, creator: @user, duration: @post.duration + 1.1)))

      assert_includes(@track.errors.full_messages, "duration (6.8s) can't be more than 1.0s longer than the post's duration (5.7s)")
    end

    should("allow a track that runs within a second past the post's duration") do
      @track = @post.audio_tracks.create(attributes_for(:audio_track).merge(creator: @user, audio_track_media_asset: build(:m4a_audio_track_media_asset, creator: @user, duration: @post.duration + 0.9)))

      assert_equal(0, @track.errors.size)
    end

    should("allow a track much shorter than the post - videos can have long silent tails") do
      @track = @post.audio_tracks.create(attributes_for(:audio_track).merge(creator: @user, audio_track_media_asset: build(:m4a_audio_track_media_asset, creator: @user, duration: @post.duration - 4.0)))

      assert_equal(0, @track.errors.size)
    end

    should("skip the duration check for a system-generated track") do
      @track = @post.audio_tracks.create(attributes_for(:audio_track).merge(creator: @user, reason: nil, is_system_generated: true, audio_track_media_asset: build(:m4a_audio_track_media_asset, creator: @user, duration: @post.duration + 100)))

      assert_equal(0, @track.errors.size)
    end
  end

  context("Processing:") do
    setup do
      # status: "pending" - these tests exercise the approve!/reject! state machine, not the
      # chunked-upload "uploading" -> "pending" handoff (AudioTrackMediaAsset#update_audio_track),
      # which only fires via the real finalize! callback, not this factory's already-active shortcut.
      @track = @post.audio_tracks.create!(attributes_for(:audio_track).merge(creator: @user, status: "pending"))
    end

    should("approve a pending track") do
      @track.approve!(@mod_user)

      assert_equal("approved", @track.status)
      assert_equal(@mod_user.id, @track.approver_id)
    end

    should("not approve a track that isn't pending") do
      @track.approve!(@mod_user)
      @track.approve!(@mod_user)

      assert_equal(["Status must be pending to approve"], @track.errors.full_messages)
    end

    should("reject a pending track with a reason") do
      @track.reject!(@mod_user, "not needed")

      assert_equal("rejected", @track.status)
      assert_equal(@mod_user.id, @track.rejector_id)
      assert_equal("not needed", @track.rejection_reason)
    end

    should("enforce only one default track per post, demoting the previous one") do
      @other = @post.audio_tracks.create!(attributes_for(:audio_track).merge(creator: @user, status: "pending"))
      @track.approve!(@mod_user, set_default: true)
      @other.approve!(@mod_user, set_default: true)

      assert(@other.reload.is_default)
      assert_not(@track.reload.is_default)
    end

    should("not allow set_default on a track that isn't approved") do
      @track.set_default!(@mod_user)

      assert_equal(["Status must be approved to set as default"], @track.errors.full_messages)
    end
  end

  context("File linkage:") do
    setup do
      @track = @post.audio_tracks.create!(attributes_for(:audio_track).merge(creator: @user, status: "approved", is_default: true))
    end

    should("tie a new track to the post's current file md5") do
      assert_equal(@post.md5, @track.file_md5)
      assert_predicate(@track, :for_current_file?)
      assert_includes(@post.approved_audio_tracks, @track)
      assert_equal(@track, @post.default_audio_track)
    end

    should("stop applying once the post's file changes, and re-apply if it reverts back") do
      original_asset_id = @post.upload_media_asset_id
      other_asset = create(:png_upload).upload_media_asset

      @post.update_column(:upload_media_asset_id, other_asset.id)
      @post.reload_media_asset

      assert_not(@track.reload.for_current_file?)
      assert_not_includes(@post.approved_audio_tracks, @track)
      assert_nil(@post.default_audio_track)

      @post.update_column(:upload_media_asset_id, original_asset_id)
      @post.reload_media_asset

      assert_predicate(@track.reload, :for_current_file?)
      assert_includes(@post.approved_audio_tracks, @track)
      assert_equal(@track, @post.default_audio_track)
    end
  end

  context("Input formats:") do
    should("accept and transcode a non-m4a upload, like mp3, to AAC/m4a") do
      asset = AudioTrackMediaAsset.new(creator: @user)
      # store! bypasses the chunked-upload finalize! lifecycle - mark active first, same as
      # AudioTrackExtractionJob does, or MediaAsset's in-progress checksum-presence check rejects it.
      asset.status = "active"
      asset.store!(@user, File.open(Rails.root.join("test/fixtures/files/test-audio.mp3")))

      assert_predicate(asset, :active?)
      assert_equal("m4a", asset.file_ext)
      assert_operator(asset.duration.to_f, :>, 0)
    end
  end
end
