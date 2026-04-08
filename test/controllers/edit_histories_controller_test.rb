# frozen_string_literal: true

require("test_helper")

class EditHistoriesControllerTest < ActionDispatch::IntegrationTest
  context("The edit histories controller") do
    setup do
      @user = create(:user)
      @mod = create(:moderator_user)
      @comment = create(:comment, creator: @user)
      @edit_history = create(:edit_history, updater: @user, versionable: @comment)
    end

    context("index action") do
      should("render") do
        get_auth(edit_histories_path, @mod)
        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::MODERATOR) { |user| get_auth(edit_histories_path, user) }
      end
    end

    context("show action") do
      should("render for a comment") do
        get_auth(comment_edits_path(@comment), @mod)
        assert_response(:success)
      end

      should("render for a forum post") do
        @forum_post = create(:forum_post, creator: @user)
        @fp_edit_history = create(:edit_history, updater: @user, versionable: @forum_post)
        get_auth(forum_post_edits_path(@forum_post), @mod)
        assert_response(:success)
      end

      should("restrict access for comments") do
        assert_access(User::Levels::MODERATOR) { |user| get_auth(comment_edits_path(@comment), user) }
      end
    end

    context("diff action") do
      setup do
        @other_edit_history = create(:edit_history, updater: @user, versionable: @comment, edit_type: "edit")
      end

      should("render when both versions are provided") do
        get_auth(diff_edit_histories_path, @mod, params: { thisversion: @edit_history.id, otherversion: @other_edit_history.id })
        assert_response(:success)
      end

      should("redirect when versions are missing") do
        get_auth(diff_edit_histories_path, @mod)
        assert_redirected_to(edit_histories_path)
      end

      should("restrict access") do
        assert_access(User::Levels::MODERATOR) { |user| get_auth(diff_edit_histories_path, user, params: { thisversion: @edit_history.id, otherversion: @other_edit_history.id }) }
      end
    end
  end
end
