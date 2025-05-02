# frozen_string_literal: true

require "test_helper"

class PostReplacementTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @user = create(:user, created_at: 2.weeks.ago)
    @mod_user = create(:moderator_user, created_at: 2.weeks.ago)
    @upload = create(:jpg_upload, uploader: @mod_user)
    @post = @upload.post
    @post.update_columns(is_pending: false, approver_id: @mod_user.id)
    CurrentUser.user = @user
  end

  context "User Limits:" do
    should "fail on too many per post in one day" do
      FemboyFans.config.stubs(:post_replacement_per_day_limit).returns(-1)
      @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_equal ["Creator has already suggested too many replacements for this post today"], @replacement.errors.full_messages
    end

    should "fail on too many per post total" do
      FemboyFans.config.stubs(:post_replacement_per_post_limit).returns(-1)
      @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_equal ["Creator already has too many pending replacements for this post"], @replacement.errors.full_messages
    end

    should "fail if user has no remaining upload limit" do
      User.any_instance.stubs(:upload_limit).returns(0)
      FemboyFans.config.stubs(:disable_throttles?).returns(false)
      @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_equal ["Creator have reached your upload limit"], @replacement.errors.full_messages
    end
  end

  context "Upload:" do
    should "allow non duplicate replacement submission" do
      @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_equal @replacement.errors.size, 0
      assert_equal @post.replacements.size, 1
      assert_equal @replacement.status, "pending"
      assert @replacement.storage_id
      assert_equal Digest::MD5.file(file_fixture("test.png")).hexdigest, Digest::MD5.file(@replacement.replacement_file_path).hexdigest
    end

    should "not allow duplicate replacement submission" do
      @replacement = @post.replacements.create(attributes_for(:jpg_replacement).merge(creator: @user))
      assert_equal("duplicate", @replacement.media_asset.status)
      assert_equal("duplicate of post ##{@post.id}", @replacement.media_asset.status_message)
    end

    should "not allow duplicate of pending replacement submission" do
      @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_equal @replacement.errors.size, 0
      assert_equal @post.replacements.size, 1
      assert_equal @replacement.status, "pending"
      assert @replacement.storage_id
      @new_replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_equal("duplicate", @new_replacement.media_asset.status)
      assert_equal("duplicate of post replacement ##{@replacement.id}", @new_replacement.media_asset.status_message)
    end

    should "not allow invalid or blank file replacements" do
      @replacement = @post.replacements.create(attributes_for(:empty_replacement).merge(creator: @user))
      assert_equal(["Data is empty"], @replacement.errors.full_messages)
      @replacement = @post.replacements.create(attributes_for(:jpg_invalid_replacement).merge(creator: @user))
      assert_equal("failed", @replacement.media_asset.status)
      assert_equal("File is corrupt", @replacement.media_asset.status_message)
    end

    should "not allow files that are too large" do
      FemboyFans.config.stubs(:max_file_sizes).returns({ "png" => 0 })
      @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_equal("failed", @replacement.media_asset.status)
      assert_equal("File size is too large. Maximum allowed for this file type is 0 Bytes", @replacement.media_asset.status_message)
    end

    should "not allow an apng that is too large" do
      FemboyFans.config.stubs(:max_apng_file_size).returns(0)
      @replacement = @post.replacements.create(attributes_for(:apng_replacement).merge(creator: @user))
      assert_equal("failed", @replacement.media_asset.status)
      assert_equal("File size is too large. Maximum allowed for this file type is 0 Bytes", @replacement.media_asset.status_message)
    end

    should "affect user upload limit" do
      assert_difference(-> { @user.post_replacements.pending.count }, 1) do
        @replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      end
    end
  end

  context "Reject:" do
    setup do
      @replacement = create(:png_replacement, creator: @user, post: @post)
      assert @replacement
    end

    should "mark replacement as rejected" do
      @replacement.reject!
      assert_equal "rejected", @replacement.status
    end

    should "allow duplicate replacement after rejection" do
      @replacement.reject!
      assert_equal("rejected", @replacement.reload.status)
      @new_replacement = @post.replacements.create(attributes_for(:png_replacement).merge(creator: @user))
      assert_equal([], @new_replacement.errors.full_messages)
      assert(@new_replacement.valid?)
    end

    should "give user back their upload slot" do
      assert_difference(-> { @user.post_replacements.pending.count }, -1) do
        @replacement.reject!
      end
    end

    should "increment the users rejected replacements count" do
      assert_difference({
        -> { @user.post_replacement_rejected_count }  => 1,
        -> { @user.post_replacements.rejected.count } => 1,
      }) do
        @replacement.reject!
        @user.reload
      end
    end

    should "work only once for pending replacements" do
      @replacement.reject!
      assert_equal [], @replacement.errors.full_messages
      @replacement.reject!
      assert_equal ["Status must be pending to reject"], @replacement.errors.full_messages
    end
  end

  context "Approve:" do
    setup do
      @note = create(:note, post: @post, x: 100, y: 200, width: 100, height: 50)
      @replacement = create(:png_replacement, creator: @user, post: @post)
    end

    should "not create a new post" do
      assert_difference({ "Post.count" => 0, "UploadMediaAsset.count" => 1 }) do
        @replacement.approve!(penalize_current_uploader: true)
      end
    end

    should "fail if post cannot be backed up" do
      @post.media_asset.md5 = "123" # Breaks file path, should force backup to fail.
      assert_raise(PostReplacement::ProcessingError) do
        @replacement.approve!(penalize_current_uploader: true)
      end
    end

    should "update post with new image" do
      old_md5 = @post.md5
      @replacement.approve!(penalize_current_uploader: true)
      @post.reload
      assert_not_equal(@post.md5, old_md5)
      assert_equal(@replacement.image_width, @post.image_width)
      assert_equal(@replacement.image_height, @post.image_height)
      assert_equal(@replacement.md5, @post.md5)
      assert_equal(@replacement.creator_id, @post.uploader_id)
      assert_equal(@replacement.file_ext, @post.file_ext)
      assert_equal(@replacement.file_size, @post.file_size)
    end

    should "work if the approver is above their upload limit" do
      User.any_instance.stubs(:upload_limit).returns(0)
      FemboyFans.config.stubs(:disable_throttles?).returns(false)

      @replacement.approve!(penalize_current_uploader: true)
      assert_equal @replacement.md5, @post.md5
    end

    should "generate videos samples if replacement is video" do
      @replacement = create(:webm_replacement, creator: @user, post: @post)
      assert_enqueued_jobs(1, only: UploadMediaAssetVideoVariantsJob) do
        @replacement.approve!(penalize_current_uploader: true)
      end
    end

    should "delete original files immediately" do
      old_media_asset = @post.media_asset
      @replacement.approve!(penalize_current_uploader: true)
      @post.reload
      old_media_asset.variants.each do |variant|
        assert_not(File.exist?(variant.file_path(protected: false)), "#{variant.type}:#{variant.ext}")
        assert_not(File.exist?(variant.file_path(protected: true)), "#{variant.type}:#{variant.ext}:protected")
      end
    end

    should "not be able to approve on deleted post" do
      @post.update_column(:is_deleted, true)
      assert_raises(PostReplacement::ProcessingError) do
        @replacement.approve!(penalize_current_uploader: true)
      end
    end

    should "create backup replacement" do
      old_md5 = @post.md5
      old_source = @post.source
      assert_difference("@post.replacements.size", 1) do
        @replacement.approve!(penalize_current_uploader: true)
      end
      new_replacement = @post.replacements.last
      assert_equal("original", new_replacement.status)
      assert_equal(old_md5, new_replacement.md5)
      assert_equal(old_source, new_replacement.source)
      sleep(60)
      assert_equal(old_md5, MediaAsset.md5(new_replacement.replacement_file_path))
    end

    should "update users upload counts" do
      assert_difference({
        -> { Post.for_user(@mod_user.id).not_flagged.not_deleted.not_pending.count } => -1,
        -> { Post.for_user(@user.id).not_flagged.not_deleted.not_pending.count }     => 1,
      }) do
        @replacement.approve!(penalize_current_uploader: true)
      end
    end

    should "update the original users upload limit if penalized" do
      assert_difference({
        -> { @mod_user.own_post_replaced_count }                                     => 1,
        -> { @mod_user.own_post_replaced_penalize_count }                            => 1,
        -> { PostReplacement.penalized.for_uploader_on_approve(@mod_user.id).count } => 1,
      }) do
        @replacement.approve!(penalize_current_uploader: true)
        @mod_user.reload
      end
    end

    should "not update the original users upload limit if not penalizing" do
      assert_difference({
        -> { @mod_user.own_post_replaced_count }                                         => 1,
        -> { @mod_user.own_post_replaced_penalize_count }                                => 0,
        -> { PostReplacement.not_penalized.for_uploader_on_approve(@mod_user.id).count } => 1,
      }) do
        @replacement.approve!(penalize_current_uploader: false)
        @mod_user.reload
      end
    end

    should "correctly resize the post's notes" do
      @replacement.approve!(penalize_current_uploader: true)
      @note.reload
      assert_equal(153, @note.x)
      assert_equal(611, @note.y)
      assert_equal(153, @note.width)
      assert_equal(152, @note.height)
    end

    should "only work on pending, original, and rejected replacements" do
      @replacement.promote!
      @replacement.approve!(penalize_current_uploader: false)
      assert_equal(["Status must be pending, original, or rejected to approve"], @replacement.errors.full_messages)
    end

    should "only work once" do
      @replacement.approve!(penalize_current_uploader: false)
      assert_equal [], @replacement.errors.full_messages
      @replacement.approve!(penalize_current_uploader: false)
      assert_equal ["Status must be pending, original, or rejected to approve"], @replacement.errors.full_messages
    end

    context "when the replacement is a webm" do
      setup do
        @replacement = create(:webm_replacement, creator: @user, post: @post)
      end

      should "detect the correct duration" do
        @replacement.approve!(penalize_current_uploader: false)
        @post.reload
        assert_equal(0.48, @post.duration)
      end

      should "update the framecount" do
        @replacement.approve!(penalize_current_uploader: false)
        assert_equal(24, @post.reload.framecount)
      end

      should "reset thumbnail_frame" do
        @post.update_column(:thumbnail_frame, 5)
        @replacement.approve!(penalize_current_uploader: false)
        assert_nil(@post.reload.thumbnail_frame)
      end
    end

    context "when the replacement is an mp4" do
      setup do
        @replacement = create(:mp4_replacement, creator: @user, post: @post)
      end

      should "detect the correct duration" do
        @replacement.approve!(penalize_current_uploader: false)
        @post.reload
        assert_equal(5.7, @post.duration)
      end

      should "update the framecount" do
        @replacement.approve!(penalize_current_uploader: false)
        assert_equal(10, @post.reload.framecount)
      end

      should "reset thumbnail_frame" do
        @post.update_column(:thumbnail_frame, 5)
        @replacement.approve!(penalize_current_uploader: false)
        assert_nil(@post.reload.thumbnail_frame)
      end
    end
  end

  context "Toggle:" do
    setup do
      @replacement = create(:png_replacement, creator: @user, post: @post)
      assert @replacement
    end

    should "change the users upload limit" do
      @replacement.approve!(penalize_current_uploader: false)
      assert_difference({
        -> { @mod_user.own_post_replaced_penalize_count }                            => 1,
        -> { PostReplacement.penalized.for_uploader_on_approve(@mod_user.id).count } => 1,
      }) do
        @replacement.toggle_penalize!
        @mod_user.reload
      end
    end

    should "only work on appoved replacements" do
      @replacement.toggle_penalize!
      assert_equal(["Status must be approved to penalize"], @replacement.errors.full_messages)
    end
  end

  context "Promote:" do
    setup do
      @replacement = create(:png_replacement, creator: @user, post: @post)
      assert @replacement
    end

    should "create a new post with replacement contents" do
      upload = @replacement.promote!
      assert(upload)
      assert_equal([], upload.errors.full_messages)
      assert_equal([], upload.post.errors.full_messages)
      assert_equal("promoted", @replacement.status)
      assert_equal(upload.md5, @replacement.md5)
      assert_equal(upload.file_ext, @replacement.file_ext)
      assert_equal(upload.image_width, @replacement.image_width)
      assert_equal(upload.image_height, @replacement.image_height)
      assert_equal(upload.tag_string.strip, @replacement.post.tag_string.strip)
      assert_equal(upload.parent_id, @replacement.post_id)
      assert_equal(upload.file_size, @replacement.file_size)
    end

    should "credit replacer with new post" do
      assert_difference({
        -> { Post.for_user(@mod_user.id).not_flagged.not_deleted.not_pending.count } => 0,
        -> { Post.for_user(@user.id).not_flagged.not_deleted.count }                 => 1,
      }) do
        upload = @replacement.promote!
        assert(upload)
        assert_equal([], upload.errors.full_messages)
        assert_equal([], upload.post.errors.full_messages)
      end
    end

    should "only work on pending replacements" do
      @replacement.approve!(penalize_current_uploader: false)
      @replacement.promote!
      assert_equal(["Status must be pending to promote"], @replacement.errors.full_messages)
    end
  end
end
