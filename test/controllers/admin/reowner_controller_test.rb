# frozen_string_literal: true

require("test_helper")

module Admin
  class ReownerControllerTest < ActionDispatch::IntegrationTest
    context("The admin reowner controller") do
      setup do
        @owner = create(:owner_user)
        @admin = create(:admin_user)
        @old_user = create(:user)
        @new_user = create(:user)
        reset_post_index
      end

      context("new action") do
        should("render") do
          get_auth(new_admin_reowner_path, @owner)
          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::OWNER) { |user| get_auth(new_admin_reowner_path, user) }
        end
      end

      context("create action") do
        should("reassign posts") do
          @post = create(:post, uploader: @old_user, uploader_ip_addr: "127.0.0.1")
          assert_difference("StaffAuditLog.count", 1) do
            post_auth(admin_reowner_path, @owner, params: { reowner: { old_owner: @old_user.name, new_owner: @new_user.name, search: "" } })
          end
          assert_redirected_to(new_admin_reowner_path)
          assert_equal(@new_user.id, @post.reload.uploader_id)
          assert_equal("post_owner_reassign", StaffAuditLog.last.action)
        end

        should("fail when old user not found") do
          post_auth(admin_reowner_path, @owner, params: { reowner: { old_owner: "nonexistent_user_xyz", new_owner: @new_user.name, search: "" } })
          assert_redirected_to(new_admin_reowner_path)
          assert_match(/failed to look up/, flash[:notice])
        end

        should("fail when new user not found") do
          post_auth(admin_reowner_path, @owner, params: { reowner: { old_owner: @old_user.name, new_owner: "nonexistent_user_xyz", search: "" } })
          assert_redirected_to(new_admin_reowner_path)
          assert_match(/failed to look up/, flash[:notice])
        end

        should("restrict access") do
          assert_access(User::Levels::OWNER, success_response: :redirect) { |user| post_auth(admin_reowner_path, user, params: { reowner: { old_owner: @old_user.name, new_owner: @new_user.name, search: "" } }) }
        end
      end
    end
  end
end
