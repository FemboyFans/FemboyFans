# frozen_string_literal: true

require "test_helper"

class ForumTopicTest < ActiveSupport::TestCase
  context "A forum topic" do
    setup do
      @user = create(:user)
      CurrentUser.user = @user
      @topic = create(:forum_topic, title: "xxx", original_post_attributes: { body: "aaa" })
    end

    context "#read_by?" do
      context "with a populated @user.last_forum_read_at" do
        setup do
          @user.update_attribute(:last_forum_read_at, Time.now)
        end

        context "and no visits for a topic" do
          setup do
            @topic.update_column(:updated_at, 1.day.from_now)
          end

          should "return false" do
            assert_equal(false, @topic.read_by?(@user))
          end

          should "return true if muted" do
            create(:forum_topic_status, user: @user, forum_topic: @topic, mute: true)
            assert_equal(true, @topic.read_by?(@user))
          end
        end

        context "and a visit for a topic" do
          setup do
            @topic.update_column(:updated_at, 1.day.from_now)
          end

          context "that predates the topic" do
            setup do
              create(:forum_topic_visit, user: @user, forum_topic: @topic, last_read_at: 16.hours.from_now)
            end

            should "return false" do
              assert_equal(false, @topic.read_by?(@user))
            end

            should "return true if muted" do
              create(:forum_topic_status, user: @user, forum_topic: @topic, mute: true)
              assert_equal(true, @topic.read_by?(@user))
            end
          end

          context "that postdates the topic" do
            setup do
              create(:forum_topic_visit, user: @user, forum_topic: @topic, last_read_at: 2.days.from_now)
            end

            should "return true" do
              assert_equal(true, @topic.read_by?(@user))
            end
          end
        end
      end

      context "with a blank @user.last_forum_read_at" do
        context "and no visits" do
          should "return false" do
            assert_equal(false, @topic.read_by?(@user))
          end

          should "return true if muted" do
            create(:forum_topic_status, user: @user, forum_topic: @topic, mute: true)
            assert_equal(true, @topic.read_by?(@user))
          end
        end

        context "and a visit" do
          context "that predates the topic" do
            setup do
              create(:forum_topic_visit, user: @user, forum_topic: @topic, last_read_at: 1.day.ago)
            end

            should "return false" do
              assert_equal(false, @topic.read_by?(@user))
            end

            should "return true if muted" do
              create(:forum_topic_status, user: @user, forum_topic: @topic, mute: true)
              assert_equal(true, @topic.read_by?(@user))
            end
          end

          context "that postdates the topic" do
            setup do
              create(:forum_topic_visit, user: @user, forum_topic: @topic, last_read_at: 1.day.from_now)
            end

            should "return true" do
              assert_equal(true, @topic.read_by?(@user))
            end
          end
        end
      end
    end

    context "#mark_as_read!" do
      context "without a previous visit" do
        should "create a new visit" do
          @topic.mark_as_read!(@user)
          @user.reload
          assert_in_delta(@topic.updated_at.to_i, @user.last_forum_read_at.to_i, 1)
        end
      end

      context "with a previous visit" do
        setup do
          create(:forum_topic_visit, user: @user, forum_topic: @topic, last_read_at: 1.day.ago)
        end

        should "update the visit" do
          @topic.mark_as_read!(@user)
          @user.reload
          assert_in_delta(@topic.updated_at.to_i, @user.last_forum_read_at.to_i, 1)
        end
      end
    end

    context "constructed with nested attributes for its original post" do
      should "create a matching forum post" do
        assert_difference(["ForumTopic.count", "ForumPost.count"], 1) do
          @topic = create(:forum_topic, title: "abc", original_post_attributes: { body: "abc" })
        end
      end
    end

    should "be searchable by title" do
      assert_equal(1, ForumTopic.attribute_matches(:title, "xxx").count)
      assert_equal(0, ForumTopic.attribute_matches(:title, "aaa").count)
    end

    should "be searchable by category id" do
      assert_equal(0, ForumTopic.search(category_id: 0).count)
      assert_equal(1, ForumTopic.search(category_id: FemboyFans.config.alias_implication_forum_category).count)
    end

    should "initialize its creator" do
      assert_equal(@user.id, @topic.creator_id)
    end

    context "updated by a second user" do
      setup do
        @second_user = create(:user)
        CurrentUser.user = @second_user
      end

      should "record its updater" do
        @topic.update(title: "abc")
        assert_equal(@second_user.id, @topic.updater_id)
      end
    end

    context "with multiple posts that has been deleted" do
      setup do
        5.times do
          create(:forum_post, topic_id: @topic.id)
        end
      end

      should "delete any associated posts" do
        assert_difference("ForumPost.count", -6) do
          @topic.destroy
        end
      end
    end

    context "that has an alias, implication, or bulk update request" do
      setup do
        @tag_alias = create(:tag_alias, forum_post: @topic.original_post)
        @topic.original_post.update_columns(tag_change_request_id: @tag_alias.id, tag_change_request_type: "TagAlias")
        @mod = create(:moderator_user)
      end

      should "only be hidable by moderators" do
        @topic.hide!

        assert_equal(["Topic is for an alias, implication, or bulk update request. It cannot be hidden"], @topic.errors.full_messages)
        assert_equal(@topic.reload.is_hidden, false)

        as(@mod) do
          @topic.hide!
        end

        assert_equal([], @topic.errors.full_messages)
        assert_equal(@topic.reload.is_hidden, true)
      end
    end
  end
end
