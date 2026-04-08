# frozen_string_literal: true

require("test_helper")

module Admin
  class BulkUpdateRequestImportsControllerTest < ActionDispatch::IntegrationTest
    context("The admin bulk update request imports controller") do
      setup do
        @owner = create(:owner_user)
        @admin = create(:admin_user)
      end

      context("new action") do
        should("render") do
          get_auth(new_admin_bulk_update_request_import_path, @owner)
          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::OWNER) { |user| get_auth(new_admin_bulk_update_request_import_path, user) }
        end
      end

      context("create action") do
        should("work with valid script") do
          create(:tag, name: "tag_a")
          create(:tag, name: "tag_b")
          post_auth(admin_bulk_update_request_import_path, @owner, params: { batch: { script: "alias tag_a -> tag_b" } })
          assert_redirected_to(new_admin_bulk_update_request_import_path)
        end

        should("fail with invalid script") do
          post_auth(admin_bulk_update_request_import_path, @owner, params: { batch: { script: "invalid script !!!" } })
          assert_response(:bad_request)
        end

        should("restrict access") do
          assert_access(User::Levels::OWNER, success_response: :bad_request) { |user| post_auth(admin_bulk_update_request_import_path, user, params: { batch: { script: "" } }) }
        end
      end
    end
  end
end
