# frozen_string_literal: true

require("test_helper")

class CommentTest < ActiveSupport::TestCase
  context("A comment") do
    setup do
      @user = create(:user)
      @mod = create(:moderator_user)
    end

    context("created by a limited user") do
      setup do
        FemboyFans.config.stubs(:disable_throttles?).returns(false)
      end

      should("fail creation") do
        comment = build(:comment, creator: @user)
        comment.save
        assert_equal(["Creator can not yet perform this action. Account is too new"], comment.errors.full_messages)
      end
    end

    context("created by an unlimited user") do
      setup do
        FemboyFans.config.stubs(:member_comment_limit).returns(100)
      end

      context("that is then deleted") do
        setup do
          @post = create(:post)
          @comment = create(:comment, post_id: @post.id)
          @comment.destroy_with(@mod)
          @post.reload
        end

        should("nullify the last_commented_at field") do
          assert_nil(@post.last_commented_at)
        end
      end

      should("be created") do
        comment = build(:comment)
        comment.save
        assert(comment.errors.empty?, comment.errors.full_messages.join(", "))
      end

      should("not validate if the post does not exist") do
        comment = build(:comment, post_id: -1)

        assert_not(comment.valid?)
        assert_match(/must exist/, comment.errors[:post].join(", "))
      end

      should("not bump the parent post") do
        post = create(:post)
        create(:comment, do_not_bump_post: true, post: post)
        post.reload
        assert_nil(post.last_comment_bumped_at)

        create(:comment, post: post)
        post.reload
        assert_not_nil(post.last_comment_bumped_at)
      end

      should("not bump the post after exceeding the threshold") do
        FemboyFans.config.stubs(:comment_threshold).returns(1)
        p = create(:post)
        c1 = create(:comment, post: p)
        travel_to(2.seconds.from_now) do
          create(:comment, post: p)
        end
        p.reload
        assert_equal(c1.created_at.to_s, p.last_comment_bumped_at.to_s)
      end

      should("always record the last_commented_at properly") do
        post = create(:post)
        FemboyFans.config.stubs(:comment_threshold).returns(1)

        c1 = create(:comment, do_not_bump_post: true, post: post)
        post.reload
        assert_equal(c1.created_at.to_s, post.last_commented_at.to_s)

        c2 = create(:comment, post: post)
        post.reload
        assert_equal(c2.created_at.to_s, post.last_commented_at.to_s)
      end

      should("not record the user id of the voter") do
        create(:user)
        user2 = create(:user)
        post = create(:post)
        c1 = create(:comment, post: post)

        VoteManager::Comments.vote!(user: user2, ip_addr: "127.0.0.1", comment: c1, score: -1)
        c1.reload
        assert_not_equal(user2.id, c1.updater_id)
      end

      should("not allow duplicate votes") do
        create(:user)
        user2 = create(:user)
        post = create(:post)
        c1 = create(:comment, post: post)
        c2 = create(:comment, post: post)

        assert_nothing_raised { VoteManager::Comments.vote!(user: user2, ip_addr: "127.0.0.1", comment: c1, score: -1) }
        assert_equal(:need_unvote, VoteManager::Comments.vote!(user: user2, ip_addr: "127.0.0.1", comment: c1, score: -1)[1])
        assert_equal(1, CommentVote.count)
        assert_equal(-1, CommentVote.last.score)

        assert_nothing_raised { VoteManager::Comments.vote!(user: user2, ip_addr: "127.0.0.1", comment: c2, score: -1) }
        assert_equal(2, CommentVote.count)
      end

      should("not allow upvotes by the creator") do
        user = create(:user)
        post = create(:post)
        c1 = create(:comment, post: post, creator: user)

        exception = assert_raises(ActiveRecord::RecordInvalid) { VoteManager::Comments.vote!(user: user, ip_addr: "127.0.0.1", comment: c1, score: 1) }
        assert_equal("Validation failed: You cannot vote on your own comments", exception.message)
      end

      should("not allow downvotes by the creator") do
        user = create(:user)
        post = create(:post)
        c1 = create(:comment, post: post, creator: user)

        exception = assert_raises(ActiveRecord::RecordInvalid) { VoteManager::Comments.vote!(user: user, ip_addr: "127.0.0.1", comment: c1, score: -1) }
        assert_equal("Validation failed: You cannot vote on your own comments", exception.message)
      end

      should("not allow votes on sticky comments") do
        user = create(:user)
        post = create(:post)
        c1 = create(:comment, post: post, is_sticky: true, creator: user)

        exception = assert_raises(ActiveRecord::RecordInvalid) { VoteManager::Comments.vote!(user: user, ip_addr: "127.0.0.1", comment: c1, score: -1) }
        assert_match(/You cannot vote on sticky comments/, exception.message)
      end

      should("allow undoing of votes") do
        user = create(:user)
        user2 = create(:user)
        post = create(:post)
        comment = create(:comment, post: post, creator: user)
        VoteManager::Comments.vote!(user: user2, ip_addr: "127.0.0.1", comment: comment, score: 1)
        comment.reload
        assert_equal(1, comment.score)
        VoteManager::Comments.unvote!(user: user2, comment: comment)
        comment.reload
        assert_equal(0, comment.score)
        assert_nothing_raised { VoteManager::Comments.vote!(user: user2, ip_addr: "127.0.0.1", comment: comment, score: -1) }
      end

      should("be searchable") do
        c1 = create(:comment, body: "aaa bbb ccc")
        c2 = create(:comment, body: "aaa ddd")
        create(:comment, body: "eee")

        matches = Comment.search_current(body_matches: "aaa")
        assert_equal(2, matches.count)
        assert_equal(c2.id, matches.all[0].id)
        assert_equal(c1.id, matches.all[1].id)
      end

      should("default to id_desc order when searched with no options specified") do
        comms = create_list(:comment, 3)
        matches = Comment.search_current({})

        assert_equal([comms[2].id, comms[1].id, comms[0].id], matches.map(&:id))
      end

      context("that is edited by a moderator") do
        setup do
          @post = create(:post)
          @comment = create(:comment, post_id: @post.id)
        end

        should("create a mod action") do
          assert_difference("ModAction.count") do
            @comment.update_with(@mod, body: "nope")
          end
        end

        should("credit the moderator as the updater") do
          @comment.update_with(@mod, body: "test")
          assert_equal(@mod.id, @comment.updater_id)
        end
      end

      context("that is hidden by a moderator") do
        setup do
          @comment = create(:comment)
        end

        should("create a mod action") do
          assert_difference("ModAction.count", 1) do
            @comment.update_with(@mod, is_hidden: true)
          end
        end

        should("credit the moderator as the updater") do
          @comment.update_with(@mod, is_hidden: true)
          assert_equal(@mod.id, @comment.updater_id)
        end
      end

      context("that is stickied by a moderator") do
        setup do
          @comment = create(:comment)
        end

        should("create a mod action") do
          assert_difference("ModAction.count", 1) do
            @comment.update_with(@mod, is_sticky: true)
          end
        end

        should("credit the moderator as the updater") do
          @comment.update_with(@mod, is_sticky: true)
          assert_equal(@mod.id, @comment.updater_id)
        end
      end

      context("that is deleted") do
        setup do
          @comment = create(:comment)
        end

        should("create a mod action") do
          assert_difference("ModAction.count", 1) do
            @comment.destroy_with(@mod)
          end
        end
      end

      context("that is below the score threshold") do
        should("be hidden if not stickied") do
          user = create(:user, comment_threshold: 0)
          post = create(:post)
          comment = create(:comment, post: post, score: -5)

          assert_equal([comment], post.comments.hidden(user))
          assert_equal([], post.comments.visible(user))
        end

        should("be visible if stickied") do
          user = create(:user, comment_threshold: 0)
          post = create(:post)
          comment = create(:comment, post: post, score: -5, is_sticky: true)

          assert_equal([], post.comments.hidden(user))
          assert_equal([comment], post.comments.visible(user))
        end
      end

      context("on a comment disabled post") do
        setup do
          @post = create(:post, is_comment_disabled: true)
        end

        should("prevent new comments") do
          comment = build(:comment, post: @post)
          comment.save
          assert_equal(["Post has comments disabled"], comment.errors.full_messages)
        end
      end

      context("on a comment locked post") do
        setup do
          @post = create(:post, is_comment_locked: true)
        end

        should("prevent new comments") do
          comment = build(:comment, post: @post)
          comment.save
          assert_equal(["Post has comments locked"], comment.errors.full_messages)
        end
      end

      context("on a comment disabled post") do
        setup do
          @post = create(:post, is_comment_disabled: true)
        end

        should("prevent new comments") do
          comment = build(:comment, post: @post)
          comment.save
          assert_equal(["Post has comments disabled"], comment.errors.full_messages)
        end
      end
    end

    context("during validation") do
      subject { build(:comment) }
      should_not(allow_value(" ").for(:body))
    end

    context("when modified") do
      setup do
        @post = create(:post)
        @comment = create(:comment, post_id: @post.id, creator: @user)
        original_body = @comment.body
        @comment.class_eval do
          after_save do
            if @body_history.nil?
              @body_history = [original_body]
            end
            @body_history.push(body)
          end

          define_method(:body_history) do
            @body_history
          end
        end
      end

      instance_exec do
        define_method(:verify_history) do |history, comment, edit_type, user = comment.creator_id|
          throw("history is nil (#{comment.id}:#{edit_type}:#{user}:#{comment.creator_id})") if history.nil?
          assert_equal(comment.body_history[history.version - 1], history.body, "history body did not match")
          assert_equal(edit_type, history.edit_type, "history edit_type did not match")
          assert_equal(user, history.updater_id, "history updater_id did not match")
        end
      end

      should("create edit histories when body is changed") do
        assert_difference("EditHistory.count", 3) do
          @comment.update_with(@user, body: "test")
          @comment.update_with(@mod, body: "test2")

          original, edit, edit2 = EditHistory.where(versionable_id: @comment.id).order(version: :asc)
          verify_history(original, @comment, "original", @user.id)
          verify_history(edit, @comment, "edit", @user.id)
          verify_history(edit2, @comment, "edit", @mod.id)
        end
      end

      should("create edit histories when hidden is changed") do
        assert_difference("EditHistory.count", 3) do
          @comment.hide!(@user)
          @comment.unhide!(@mod)

          original, hide, unhide = EditHistory.where(versionable_id: @comment.id).order(version: :asc)
          verify_history(original, @comment, "original")
          verify_history(hide, @comment, "hide")
          verify_history(unhide, @comment, "unhide", @mod.id)
        end
      end

      should("create edit histories when sticky is changed") do
        assert_difference("EditHistory.count", 3) do
          @comment.update_with(@mod, is_sticky: true)

          @comment.update_with(@mod, is_sticky: false)
          original, stick, unstick = EditHistory.where(versionable_id: @comment.id).order(version: :asc)
          verify_history(original, @comment, "original")
          verify_history(stick, @comment, "stick", @mod.id)
          verify_history(unstick, @comment, "unstick", @mod.id)
        end
      end

      should("create edit histories when warning is changed") do
        assert_difference("EditHistory.count", 7) do
          @comment.user_warned!("warning", @mod)
          @comment.remove_user_warning!(@mod)
          @comment.user_warned!("record", @mod)
          @comment.remove_user_warning!(@mod)
          @comment.user_warned!("ban", @mod)
          @comment.remove_user_warning!(@mod)

          original, warn, unmark1, record, unmark2, ban, unmark3 = EditHistory.where(versionable_id: @comment.id).order(version: :asc)
          verify_history(original, @comment, "original")
          verify_history(warn, @comment, "mark_warning", @mod.id)
          verify_history(unmark1, @comment, "unmark", @mod.id)
          verify_history(record, @comment, "mark_record", @mod.id)
          verify_history(unmark2, @comment, "unmark", @mod.id)
          verify_history(ban, @comment, "mark_ban", @mod.id)
          verify_history(unmark3, @comment, "unmark", @mod.id)
        end
      end
    end
  end
end
