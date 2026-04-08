# frozen_string_literal: true

require("test_helper")

class UploadWhitelistsControllerTest < ActionDispatch::IntegrationTest
  context("The upload whitelists controller") do
    setup do
      @admin = create(:admin_user)
      @user = create(:user)
      @whitelist = create(:upload_whitelist, pattern: "example.com", creator: @admin)
    end

    context("index action") do
      should("render") do
        get_auth(upload_whitelists_path, @admin)
        assert_response(:success)
      end

      should("render with search params") do
        get_auth(upload_whitelists_path, @admin, params: { search: { pattern: "example.com" } })
        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER) { |user| get_auth(upload_whitelists_path, user) }
      end
    end

    context("new action") do
      should("render") do
        get_auth(new_upload_whitelist_path, @admin)
        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN) { |user| get_auth(new_upload_whitelist_path, user) }
      end
    end

    context("edit action") do
      should("render") do
        get_auth(edit_upload_whitelist_path(@whitelist), @admin)
        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN) { |user| get_auth(edit_upload_whitelist_path(@whitelist), user) }
      end
    end

    context("create action") do
      should("work") do
        assert_difference("UploadWhitelist.count", 1) do
          post_auth(upload_whitelists_path, @admin, params: { upload_whitelist: { pattern: "newsite.com", allowed: true, note: "test" } })
        end
        assert_redirected_to(upload_whitelists_path)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| post_auth(upload_whitelists_path, user, params: { upload_whitelist: { pattern: "site_#{SecureRandom.hex(4)}.com", allowed: true } }) }
      end
    end

    context("update action") do
      should("work") do
        put_auth(upload_whitelist_path(@whitelist), @admin, params: { upload_whitelist: { note: "updated note" } })
        assert_redirected_to(upload_whitelists_path)
        assert_equal("updated note", @whitelist.reload.note)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| put_auth(upload_whitelist_path(@whitelist), user, params: { upload_whitelist: { note: "test" } }) }
      end
    end

    context("destroy action") do
      should("work") do
        assert_difference("UploadWhitelist.count", -1) do
          delete_auth(upload_whitelist_path(@whitelist), @admin)
        end
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| delete_auth(upload_whitelist_path(create(:upload_whitelist, pattern: "site_#{SecureRandom.hex(4)}.com", creator: @admin)), user) }
      end
    end

    context("is_allowed action") do
      should("return allowed for a whitelisted url") do
        @whitelist.update_columns(allowed: true)
        get_auth(is_allowed_upload_whitelists_path, @user, params: { url: "http://example.com/image.png", format: :json })
        assert_response(:success)
        json = response.parsed_body
        assert_equal(true, json["is_allowed"])
      end

      should("return not allowed for a blocked url") do
        @whitelist.update_columns(allowed: false)
        get_auth(is_allowed_upload_whitelists_path, @user, params: { url: "http://example.com/image.png", format: :json })
        assert_response(:success)
        json = response.parsed_body
        assert_equal(false, json["is_allowed"])
      end

      should("handle invalid urls") do
        get_auth(is_allowed_upload_whitelists_path, @user, params: { url: "not a valid url ://", format: :json })
        assert_response(:success)
        json = response.parsed_body
        assert_equal(false, json["is_allowed"])
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER) { |user| get_auth(is_allowed_upload_whitelists_path, user, params: { url: "http://example.com/image.png", format: :json }) }
      end
    end
  end
end
