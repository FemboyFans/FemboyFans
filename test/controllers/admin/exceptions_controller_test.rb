# frozen_string_literal: true

require("test_helper")

module Admin
  class ExceptionsControllerTest < ActionDispatch::IntegrationTest
    context("The admin exceptions controller") do
      setup do
        @admin = create(:admin_user)
        @exception_log = ExceptionLog.add!(StandardError.new("test error"), user_id: @admin.id)
      end

      context("index action") do
        should("render") do
          get_auth(admin_exceptions_path, @admin)
          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN) { |user| get_auth(admin_exceptions_path, user) }
        end
      end

      context("show action") do
        should("render by id") do
          get_auth(admin_exception_path(@exception_log.id), @admin)
          assert_response(:success)
        end

        should("render by code") do
          get_auth(admin_exception_path(@exception_log.code), @admin)
          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN) { |user| get_auth(admin_exception_path(@exception_log.id), user) }
        end
      end
    end
  end
end
