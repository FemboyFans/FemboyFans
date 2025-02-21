# frozen_string_literal: true

require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  context "The posts controller" do
    setup do
      @admin = create(:admin_user)
      @user = create(:user, created_at: 1.month.ago)
      as(@user) do
        @post = create(:post, tag_string: "aaaa")
      end
    end

    context "index action" do
      should "render" do
        get posts_path
        assert_response :success
      end

      context "with a search" do
        should "render" do
          get posts_path, params: { tags: "aaaa" }
          assert_response :success
        end
      end

      context "with an md5 param" do
        should "render" do
          get posts_path, params: { md5: @post.md5 }
          assert_redirected_to(@post)
        end

        should "return error on nonexistent md5" do
          get posts_path(md5: "foo")
          assert_response 404
        end
      end

      context "with a random search" do
        should "render" do
          get posts_path, params: { tags: "order:random" }
          assert_response :success

          get posts_path, params: { random: "1" }
          assert_response :success
        end
      end

      should "restrict access" do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth posts_path, user }
      end
    end

    context "show_seq action" do
      should "render" do
        posts = create_list(:post, 3)

        get show_seq_post_path(posts[1].id), params: { seq: "prev" }
        assert_response :success

        get show_seq_post_path(posts[1].id), params: { seq: "next" }
        assert_response :success
      end

      should "restrict access" do
        @posts = create_list(:post, 2)
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth show_seq_post_path(@posts.first.id, params: { seq: "next" }), user }
      end
    end

    context "show action" do
      should "render" do
        get post_path(@post)
        assert_response :success
      end

      should "restrict access" do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth post_path(@post), user }
      end
    end

    context "update action" do
      should "work" do
        put_auth post_path(@post), @user, params: { post: { tag_string: "bbb" } }
        assert_redirected_to post_path(@post)

        @post.reload
        assert_equal("bbb", @post.tag_string)
      end

      should "ignore restricted params" do
        put_auth post_path(@post), @user, params: { post: { last_noted_at: 1.minute.ago } }
        assert_nil(@post.reload.last_noted_at)
      end

      should "generate the correct thumbnail" do
        post = UploadService.new(attributes_for(:upload).merge(file: fixture_file_upload("test-512x512.webm"), uploader: @admin, tag_string: "tst")).start!.post
        assert_equal("77ecd5e8577a03090d3864d348d7020b", Digest::MD5.file(post.reload.preview_file_path).hexdigest)
        assert_difference("PostEvent.count", 1) do
          assert_enqueued_jobs(1, only: PostImageSampleJob) do
            put_auth post_path(post), @admin, params: { post: { thumbnail_frame: 5 }, format: :json }
          end
        end
        assert_response :success
        perform_enqueued_jobs(only: PostImageSampleJob)
        assert_equal("79bb226d5656a47979fdcb94a5feb16a", Digest::MD5.file(post.reload.preview_file_path).hexdigest)
      end

      should "not allow setting thumbnail_frame on posts where framecount=0" do
        @post.update_column(:framecount, 0)
        put_auth post_path(@post), @admin, params: { post: { thumbnail_frame: 1 }, format: :json }
        assert_response :unprocessable_entity
        assert_same_elements(["Thumbnail frame cannot be used on posts without a framecount"], @response.parsed_body[:message]&.split("; "))
      end

      should "not allow setting thumbnail_frame greater than framecount" do
        @post.update_column(:framecount, 10)
        put_auth post_path(@post), @admin, params: { post: { thumbnail_frame: 11 }, format: :json }
        assert_response :unprocessable_entity
        assert_same_elements(["Thumbnail frame must be between 1 and 10"], @response.parsed_body[:message]&.split("; "))
      end

      should "not allow setting thumbnail_frame further than 10% from the start if framecount is greater than 1000" do
        @post.update_column(:framecount, 1500)
        put_auth post_path(@post), @admin, params: { post: { thumbnail_frame: 2000 }, format: :json }
        assert_response :unprocessable_entity
        assert_same_elements(["Thumbnail frame must be between 1 and 150", "Thumbnail frame must be in first 10% of video"], @response.parsed_body[:message]&.split("; "))
      end

      context "min_edit_level" do
        setup do
          @post.update_column(:min_edit_level, User::Levels::TRUSTED)
        end

        should "prevent edits when the editors level is lower" do
          put_auth post_path(@post), @user, params: { post: { tag_string: "test" }, format: :json }
          assert_response :forbidden
        end

        should "allow edits when the editors level is higher" do
          put_auth post_path(@post), @admin, params: { post: { tag_string: "test" }, format: :json }
          assert_response :success
        end
      end

      should "restrict access" do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| put_auth post_path(@post), user, params: { post: { tag_string: "bbb" } } }
      end
    end

    context "revert action" do
      setup do
        as(@user) do
          @post.update(tag_string: "zzz")
        end
      end

      should "work" do
        @version = @post.versions.first
        assert_equal("aaaa", @version.tags)
        put_auth revert_post_path(@post), @user, params: { version_id: @version.id }
        assert_redirected_to post_path(@post)
        @post.reload
        assert_equal("aaaa", @post.tag_string)
      end

      should "not allow reverting to a previous version of another post" do
        as(@user) do
          @post2 = create(:post, uploader_id: @user.id, tag_string: "herp")
        end

        put_auth revert_post_path(@post), @user, params: { version_id: @post2.versions.first.id }
        @post.reload
        assert_not_equal(@post.tag_string, @post2.tag_string)
        assert_response :missing
      end

      context "min_edit_level" do
        setup do
          @post.update_column(:min_edit_level, User::Levels::TRUSTED)
        end

        should "prevent edits when the editors level is lower" do
          put_auth revert_post_path(@post), @user, params: { version_id: @post.versions.first.id, format: :json }
          assert_response :forbidden
        end

        should "allow edits when the editors level is higher" do
          put_auth revert_post_path(@post), @admin, params: { version_id: @post.versions.first.id, format: :json }
          assert_response :success
        end
      end

      should "restrict access" do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| put_auth revert_post_path(@post), user, params: { version_id: @post.versions.first.id } }
      end
    end

    context "delete action" do
      should "render" do
        get_auth delete_post_path(@post), @admin
        assert_response :success
      end

      should "restrict access" do
        assert_access([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]) { |user| get_auth delete_post_path(@post), user }
      end
    end

    context "destroy action" do
      should "work" do
        delete_auth post_path(@post), @admin, params: { reason: "xxx" }
        assert(@post.reload.is_deleted?)
        assert_equal(true, @post.uploader.notifications.post_delete.exists?)
      end

      should "work even if the deleter has flagged the post previously" do
        as(@user) do
          PostFlag.create(post: @post, reason: "aaa", is_resolved: false)
        end
        delete_auth post_path(@post), @admin, params: { reason: "xxx" }
        assert(@post.reload.is_deleted?)
      end

      should "restrict access" do
        assert_access([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER], success_response: :redirect) { |user| delete_auth post_path(@post), user }
      end
    end

    context "undelete action" do
      should "work" do
        as(@user) do
          @post.delete!("test delete")
        end
        assert_difference(-> { PostEvent.count }, 1) do
          put_auth undelete_post_path(@post), @admin, params: { format: :json }
        end

        assert_response :success
        assert_not(@post.reload.is_deleted?)
        assert_equal(true, @post.uploader.notifications.post_undelete.exists?)
      end

      should "restrict access" do
        assert_access([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER], success_response: :redirect) { |user| put_auth undelete_post_path(create(:post, is_deleted: true)), user }
      end
    end

    context "expunge action" do
      should "work" do
        put_auth expunge_post_path(@post), @admin, params: { format: :json }

        assert_response :success
        assert_equal(false, ::Post.exists?(@post.id))
      end

      should "work with reason" do
        put_auth expunge_post_path(@post), @admin, params: { reason: "test", format: :json }

        assert_response :success
        assert_equal(false, ::Post.exists?(@post.id))
        assert_equal("test", DestroyedPost.last.reason)
      end

      should "restrict access" do
        assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| put_auth expunge_post_path(create(:post)), user }
      end
    end

    context "add_to_pool action" do
      setup do
        as(@user) do
          @pool = create(:pool, name: "abc")
        end
      end

      should "add a post to a pool" do
        post_auth add_to_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json }
        @pool.reload
        assert_equal([@post.id], @pool.post_ids)
      end

      should "add a post to a pool once and only once" do
        as(@user) { @pool.add!(@post) }
        post_auth add_to_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json }
        @pool.reload
        assert_equal([@post.id], @pool.post_ids)
      end

      should "update the pool's artists" do
        as(@user) { @post.update(tag_string: "artist:foo") }
        perform_enqueued_jobs(only: UpdatePoolArtistsJob)
        assert_equal([], @pool.artist_names)
        post_auth add_to_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json }
        perform_enqueued_jobs(only: UpdatePoolArtistsJob)
        assert_same_elements(%w[foo], @pool.reload.artist_names)
      end

      context "min_edit_level" do
        setup do
          @post.update_columns(min_edit_level: User::Levels::TRUSTED)
        end

        should "prevent edits when the editors level is lower" do
          post_auth add_to_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json }
          assert_response :forbidden
        end

        should "allow edits when the editors level is higher" do
          post_auth add_to_pool_post_path(@post), @admin, params: { pool_id: @pool.id, format: :json }
          assert_response :success
        end
      end

      should "restrict access" do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| post_auth add_to_pool_post_path(@post), user, params: { pool_id: @pool.id } }
      end
    end

    context "remove_from_pool action" do
      setup do
        as(@user) do
          @pool = create(:pool, name: "abc")
          @pool.add!(@post)
        end
      end

      should "remove a post from a pool" do
        post_auth remove_from_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json }
        @pool.reload
        assert_equal([], @pool.post_ids)
      end

      should "do nothing if the post is not a member of the pool" do
        @pool.reload
        as(@user) do
          @pool.remove!(@post)
        end
        post_auth remove_from_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json }
        @pool.reload
        assert_equal([], @pool.post_ids)
      end

      should "update the pool's artists" do
        as(@user) { @post.update(tag_string: "artist:foo") }
        perform_enqueued_jobs(only: UpdatePoolArtistsJob)
        assert_same_elements(%w[foo], @pool.reload.artist_names)
        post_auth remove_from_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json }
        perform_enqueued_jobs(only: UpdatePoolArtistsJob)
        assert_equal([], @pool.reload.artist_names)
      end

      context "min_edit_level" do
        setup do
          @post.update_columns(min_edit_level: User::Levels::TRUSTED)
        end

        should "prevent edits when the editors level is lower" do
          post_auth remove_from_pool_post_path(@post), @user, params: { pool_id: @pool.id, format: :json }
          assert_response :forbidden
        end

        should "allow edits when the editors level is higher" do
          post_auth remove_from_pool_post_path(@post), @admin, params: { pool_id: @pool.id, format: :json }
          assert_response :success
        end
      end

      should "restrict access" do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| post_auth remove_from_pool_post_path(@post), user, params: { pool_id: @pool.id } }
      end
    end

    context "uploaders action" do
      should "render" do
        get_auth uploaders_posts_path, @admin
        assert_response :success
      end

      should "restrict access" do
        assert_access(User::Levels::JANITOR) { |user| get_auth uploaders_posts_path, user }
      end
    end

    context "deleted action" do
      should "render" do
        get deleted_posts_path
        assert_response :success
      end

      should "restrict access" do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth deleted_posts_path, user }
      end
    end
  end
end
