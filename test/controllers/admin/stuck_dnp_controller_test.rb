# frozen_string_literal: true

require("test_helper")

module Admin
  class StuckDnpControllerTest < ActionDispatch::IntegrationTest
    context("The admin stuck dnp controller") do
      setup do
        @admin = create(:admin_user)
        @user = create(:user)
        reset_post_index
      end

      context("new action") do
        should("render") do
          get_auth(new_admin_stuck_dnp_path, @admin)
          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN) { |user| get_auth(new_admin_stuck_dnp_path, user) }
        end
      end

      context("create action") do
        should("redirect when query is blank") do
          post_auth(admin_stuck_dnp_path, @admin, params: { stuck_dnp: { query: "" } })
          assert_redirected_to(new_admin_stuck_dnp_path)
          assert_match(/No query specified/, flash[:notice])
        end

        should("remove dnp tags from posts") do
          @post = create(:post, tag_string: "avoid_posting some_tag")
          assert_difference("StaffAuditLog.count", 1) do
            post_auth(admin_stuck_dnp_path, @admin, params: { stuck_dnp: { query: "some_tag" } })
          end
          assert_redirected_to(new_admin_stuck_dnp_path)
          assert_match(/DNP tags removed from/, flash[:notice])
          assert_not_includes(@post.reload.tag_string.split, "avoid_posting")
          assert_equal("stuck_dnp", StaffAuditLog.last.action)
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| post_auth(admin_stuck_dnp_path, user, params: { stuck_dnp: { query: "" } }) }
        end
      end
    end
  end
end
