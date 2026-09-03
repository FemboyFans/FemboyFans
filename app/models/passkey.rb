# frozen_string_literal: true

class Passkey < ApplicationRecord
  belongs_to_user(:user)

  validates(:label, length: { maximum: 100 })
  validates(:external_id, uniqueness: true)

  CHALLENGE_PURPOSE = :passkey_challenge

  def self.relying_party
    # The WebAuthn RP ID must be a bare hostname - no scheme, no port (config.domain carries a
    # port in dev, e.g. "localhost:4000", which browsers reject as an RP ID) - so this derives it
    # from the origin's host rather than using config.domain directly.
    ::WebAuthn::RelyingParty.new(
      id:              URI.parse(GayFurCity.config.hostname).host,
      name:            AdminConfig.instance.canonical_app_name,
      allowed_origins: [GayFurCity.config.hostname],
    )
  end

  # Registration options (navigator.credentials.create) for a user adding a new passkey. The
  # challenge is returned separately, signed, since this app doesn't rely on session state for
  # these flows (the login/2FA ceremony below happens before the user has an authenticated
  # session at all).
  def self.options_for_registration(user)
    user.update_column(:webauthn_id, ::WebAuthn.generate_user_id) if user.webauthn_id.blank?
    options = ::WebAuthn::Credential.options_for_create(
      user:          { id: user.webauthn_id, name: user.name, display_name: user.name },
      exclude:       user.passkeys.pluck(:external_id),
      relying_party: relying_party,
    )
    [options, sign_challenge(options.challenge, user)]
  end

  # Authentication options (navigator.credentials.get) for a login/2FA/reauthentication ceremony.
  def self.options_for_authentication(user)
    options = ::WebAuthn::Credential.options_for_get(
      allow:         user.passkeys.pluck(:external_id),
      relying_party: relying_party,
    )
    [options, sign_challenge(options.challenge, user)]
  end

  # Verifies a browser registration response and stores the resulting passkey. Returns the new
  # Passkey, or nil if the challenge or attestation didn't check out.
  def self.register!(user, credential_response, signed_challenge, label: nil)
    challenge = verify_challenge!(signed_challenge, user)
    webauthn_credential = ::WebAuthn::Credential.from_create(credential_response, relying_party: relying_party)
    webauthn_credential.verify(challenge)

    user.passkeys.create!(
      external_id: webauthn_credential.id,
      public_key:  webauthn_credential.public_key,
      sign_count:  webauthn_credential.sign_count,
      label:       label.presence || "Passkey",
    )
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ::WebAuthn::Error, ActiveRecord::RecordInvalid
    nil
  end

  # Verifies a browser authentication (assertion) response against one of the user's registered
  # passkeys. Returns the Passkey that was used, or nil if verification failed.
  def self.authenticate(user, credential_response, signed_challenge)
    challenge = verify_challenge!(signed_challenge, user)
    webauthn_credential = ::WebAuthn::Credential.from_get(credential_response, relying_party: relying_party)
    passkey = user.passkeys.find_by(external_id: webauthn_credential.id)
    return nil unless passkey

    webauthn_credential.verify(challenge, public_key: passkey.public_key, sign_count: passkey.sign_count)
    passkey.update!(sign_count: webauthn_credential.sign_count, last_used_at: Time.now)
    passkey
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ::WebAuthn::Error
    nil
  end

  def self.sign_challenge(challenge, user)
    GayFurCity::MessageVerifier.new(CHALLENGE_PURPOSE).generate({ challenge: challenge, user_id: user.id }, expires_in: 5.minutes)
  end

  def self.verify_challenge!(signed_challenge, user)
    payload = GayFurCity::MessageVerifier.new(CHALLENGE_PURPOSE).verify(signed_challenge)
    raise(ActiveSupport::MessageVerifier::InvalidSignature) unless payload["user_id"] == user.id
    payload["challenge"]
  end
end
