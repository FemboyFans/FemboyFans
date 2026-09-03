# frozen_string_literal: true

require("test_helper")

class PasskeyTest < ActiveSupport::TestCase
  alias fake_client fake_webauthn_client
  alias register_fake_passkey register_fake_passkey_for

  context("A passkey") do
    setup do
      @user = create(:user, created_at: 1.month.ago)
    end

    context("registration") do
      should("succeed with a valid ceremony and store the credential") do
        assert_difference("Passkey.count", 1) do
          passkey = register_fake_passkey(@user, label: "My Phone")

          assert_not_nil(passkey)
          assert_equal("My Phone", passkey.label)
          assert_equal(@user.id, passkey.user_id)
          assert_equal(0, passkey.sign_count)
        end
        assert_not_nil(@user.reload.webauthn_id)
      end

      should("default the label when blank") do
        passkey = register_fake_passkey(@user, label: "")

        assert_equal("Passkey", passkey.label)
      end

      should("reject a tampered signed challenge") do
        options, = Passkey.options_for_registration(@user)
        response = fake_client.create(challenge: options.challenge)

        assert_no_difference("Passkey.count") do
          assert_nil(Passkey.register!(@user, response, "not-a-real-token"))
        end
      end

      should("reject a signed challenge issued for a different user") do
        other_user = create(:user)
        options, signed_challenge = Passkey.options_for_registration(other_user)
        response = fake_client.create(challenge: options.challenge)

        assert_nil(Passkey.register!(@user, response, signed_challenge))
      end

      should("reject a response whose challenge doesn't match what was signed") do
        _options, signed_challenge = Passkey.options_for_registration(@user)
        mismatched_options, = Passkey.options_for_registration(@user)
        response = fake_client.create(challenge: mismatched_options.challenge)

        assert_nil(Passkey.register!(@user, response, signed_challenge))
      end

      should("reject a response from the wrong origin") do
        options, signed_challenge = Passkey.options_for_registration(@user)
        response = WebAuthn::FakeClient.new("https://evil.example").create(challenge: options.challenge)

        assert_nil(Passkey.register!(@user, response, signed_challenge))
      end
    end

    context("authentication") do
      setup { @passkey = register_fake_passkey(@user) }

      should("succeed with a valid ceremony and update sign_count/last_used_at") do
        options, signed_challenge = Passkey.options_for_authentication(@user)
        response = fake_client.get(challenge: options.challenge, allow_credentials: [@passkey.external_id])

        result = Passkey.authenticate(@user, response, signed_challenge)

        assert_equal(@passkey, result)
        assert_not_nil(@passkey.reload.last_used_at)
      end

      should("reject an assertion for a credential the user doesn't have") do
        # A credential known only to this other authenticator, never stored as one of the user's
        # Passkey rows.
        stranger_client = WebAuthn::FakeClient.new(GayFurCity.config.hostname)
        stranger_client.create(challenge: Passkey.options_for_registration(@user).first.challenge)

        options, signed_challenge = Passkey.options_for_authentication(@user)
        response = stranger_client.get(challenge: options.challenge)

        assert_nil(Passkey.authenticate(@user, response, signed_challenge))
      end

      should("reject a tampered signed challenge") do
        options, = Passkey.options_for_authentication(@user)
        response = fake_client.get(challenge: options.challenge, allow_credentials: [@passkey.external_id])

        assert_nil(Passkey.authenticate(@user, response, "not-a-real-token"))
      end

      should("include only the user's own credentials in the allow list") do
        options, = Passkey.options_for_authentication(@user)

        assert_equal([@passkey.external_id], options.allow_credentials.map { |c| c[:id] })
      end
    end
  end
end
