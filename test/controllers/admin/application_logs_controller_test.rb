# frozen_string_literal: true

require("test_helper")

module Admin
  class ApplicationLogsControllerTest < ActionDispatch::IntegrationTest
    context("The admin application logs controller") do
      setup do
        @owner = create(:owner_user)
        @path = Rails.root.join("tmp/application-log-test.log")
        File.write(@path, "oldest line\nmiddle line\nnewest line\n")
        Admin::ApplicationLog.stubs(:path_for).returns(@path)
        stub_env_config(:enable_application_logs, true)
      end

      teardown do
        FileUtils.rm_f(@path)
      end

      context("index action") do
        should("render the log lines from newest to oldest") do
          get_auth(admin_application_logs_path, @owner)

          assert_response(:success)
          assert_operator(@response.body.index("newest line"), :<, @response.body.index("middle line"))
          assert_operator(@response.body.index("middle line"), :<, @response.body.index("oldest line"))
          assert_includes(@response.body, @path.to_s)
        end

        should("render ansi colored output") do
          File.write(@path, "plain\n␛[1m␛[36mcyan bold␛[0m\n")

          get_auth(admin_application_logs_path, @owner)

          assert_response(:success)
          assert_includes(@response.body, "cyan bold")
          assert_includes(@response.body, "font-weight: bold; color: #66d9ef")
          assert_not_includes(@response.body, "␛[36m")
        end

        should("only respond to html") do
          get_auth(admin_application_logs_path(format: :json), @owner)

          assert_response(:not_acceptable)
        end

        should("not work when disabled") do
          stub_env_config(:enable_application_logs, false)
          get_auth(admin_application_logs_path, @owner)

          assert_response(:forbidden)
        end

        should("restrict access") do
          assert_access([User::Levels::OWNER]) { |user| get_auth(admin_application_logs_path, user) }
        end
      end

      context("status action") do
        should("report how many new lines were added") do
          get_auth(status_admin_application_logs_path(format: :json), @owner, params: { count: 2 })

          assert_response(:success)
          assert_equal(3, @response.parsed_body["total_count"])
          assert_equal(1, @response.parsed_body["new_lines"])
        end

        should("not work when disabled") do
          stub_env_config(:enable_application_logs, false)
          get_auth(status_admin_application_logs_path(format: :json), @owner)

          assert_response(:forbidden)
        end

        should("restrict access") do
          assert_access([User::Levels::OWNER], success_response: :success, anonymous_response: :forbidden) do |user|
            get_auth(status_admin_application_logs_path(format: :json), user)
          end
        end
      end
    end
  end
end
