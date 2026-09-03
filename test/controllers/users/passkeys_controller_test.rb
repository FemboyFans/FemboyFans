# frozen_string_literal: true

require("test_helper")

module Users
  class PasskeysControllerTest < ActionDispatch::IntegrationTest
    context("The user passkeys controller") do
      setup do
        @user = create(:user)
      end

      context("index action") do
        should("render") do
          assert_nothing_raised { get_auth(user_passkeys_path, @user) }
        end

        should("list the user's registered passkeys") do
          # Registering a passkey makes the account require 2FA, which login_as (behind get_auth)
          # doesn't know how to satisfy for a passkey - so authenticate first, while the account
          # still has none, then register and re-request over the now-authenticated session.
          get_auth(user_passkeys_path, @user)
          passkey = register_fake_passkey_for(@user, label: "My Phone")

          get(user_passkeys_path)

          assert_response(:success)
          assert_select("td", text: "My Phone")
          assert_not_nil(passkey)
        end

        should("not be accessible to anonymous users") do
          get(user_passkeys_path)

          assert_response(:redirect)
        end
      end

      context("new action") do
        should("render") do
          assert_nothing_raised { get_auth(new_user_passkey_path, @user) }
        end

        should("not be accessible to anonymous users") do
          get(new_user_passkey_path)

          assert_response(:redirect)
        end
      end

      context("create action") do
        should("register a new passkey") do
          options, signed_challenge = Passkey.options_for_registration(@user)
          credential = fake_webauthn_client.create(challenge: options.challenge)

          assert_difference("Passkey.count", 1) do
            post_auth(user_passkeys_path, @user, params: { passkey: { credential: credential.to_json, signed_challenge: signed_challenge, label: "Work laptop" } })

            assert_redirected_to(user_passkeys_path)
          end
          assert_equal("Work laptop", @user.passkeys.last.label)
          assert_predicate(@user.user_events.passkey_add, :exists?)
        end

        should("generate backup codes the first time 2FA is enabled") do
          options, signed_challenge = Passkey.options_for_registration(@user)
          credential = fake_webauthn_client.create(challenge: options.challenge)

          assert_nil(@user.backup_codes)
          post_auth(user_passkeys_path, @user, params: { passkey: { credential: credential.to_json, signed_challenge: signed_challenge } })

          assert_not_empty(@user.reload.backup_codes)
        end

        should("not register a passkey with a tampered signed challenge") do
          options, = Passkey.options_for_registration(@user)
          credential = fake_webauthn_client.create(challenge: options.challenge)

          assert_no_difference("Passkey.count") do
            post_auth(user_passkeys_path, @user, params: { passkey: { credential: credential.to_json, signed_challenge: "not-a-real-token" } })

            assert_redirected_to(new_user_passkey_path)
          end
        end

        should("not be accessible to anonymous users") do
          post(user_passkeys_path, params: { passkey: { credential: "{}", signed_challenge: "x" } })

          assert_response(:redirect)
        end
      end

      context("destroy action") do
        should("remove the passkey") do
          get_auth(user_passkeys_path, @user)
          passkey = register_fake_passkey_for(@user)

          delete(user_passkey_path(passkey))

          assert_redirected_to(user_passkeys_path)
          assert_raises(ActiveRecord::RecordNotFound) { passkey.reload }
          assert_predicate(@user.user_events.passkey_remove, :exists?)
        end

        should("not allow removing another user's passkey") do
          other_user = create(:user)
          passkey = register_fake_passkey_for(other_user)

          delete_auth(user_passkey_path(passkey), @user, params: { format: :json })

          assert_response(:forbidden)
          assert_nothing_raised { passkey.reload }
        end

        should("clear backup codes once the last 2FA method is removed") do
          get_auth(user_passkeys_path, @user)
          passkey = register_fake_passkey_for(@user)
          @user.regenerate_backup_codes!(mock_request)

          assert_not_empty(@user.reload.backup_codes)

          delete(user_passkey_path(passkey))

          assert_nil(@user.reload.backup_codes)
        end

        should("not be accessible to anonymous users") do
          passkey = register_fake_passkey_for(@user)

          delete(user_passkey_path(passkey))

          assert_response(:redirect)
          assert_nothing_raised { passkey.reload }
        end

        should("keep backup codes if TOTP is still enabled") do
          get_auth(user_passkeys_path, @user)
          passkey = register_fake_passkey_for(@user)
          mfa = ::MFA.new(username: @user.name)
          @user.update_mfa_secret!(mfa.secret, mock_request)
          @user.regenerate_backup_codes!(mock_request)

          assert_not_empty(@user.reload.backup_codes)

          delete(user_passkey_path(passkey))

          assert_not_empty(@user.reload.backup_codes)
        end
      end
    end
  end
end
