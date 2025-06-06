# frozen_string_literal: true

require("test_helper")

module Users
  class LoginRemindersControllerTest < ActionDispatch::IntegrationTest
    context("A login reminder controller") do
      setup do
        @user = create(:user)
        @blank_email_user = create(:user, email: "")
        ActionMailer::Base.delivery_method = :test
        ActionMailer::Base.deliveries.clear
      end

      should("render the new page") do
        get(new_users_login_reminder_path)
        assert_response(:success)
      end

      should("deliver an email with the login to the user") do
        post(users_login_reminder_path, params: { user: { email: @user.email } })
        assert_equal(1, ActionMailer::Base.deliveries.size)
      end

      context("for a user with a blank email") do
        should("fail") do
          post(users_login_reminder_path, params: { user: { email: "" } })
          @blank_email_user.reload
          assert_in_delta(@blank_email_user.created_at.to_i, @blank_email_user.updated_at.to_i, 1)
          assert_equal(0, ActionMailer::Base.deliveries.size)
        end
      end
    end
  end
end
