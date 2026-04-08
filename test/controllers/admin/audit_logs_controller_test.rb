# frozen_string_literal: true

require("test_helper")

module Admin
  class AuditLogsControllerTest < ActionDispatch::IntegrationTest
    context("The admin audit logs controller") do
      setup do
        @admin = create(:admin_user)
        @mod = create(:moderator_user)
        StaffAuditLog.log!(@admin, :test_action, reason: "test")
      end

      context("index action") do
        should("render") do
          get_auth(admin_audit_logs_path, @mod)
          assert_response(:success)
        end

        should("render with search params") do
          get_auth(admin_audit_logs_path, @mod, params: { search: { action: "test_action" } })
          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::MODERATOR) { |user| get_auth(admin_audit_logs_path, user) }
        end
      end
    end
  end
end
