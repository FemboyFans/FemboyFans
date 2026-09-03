# frozen_string_literal: true

class CreatePasskeys < ActiveRecord::Migration[8.1]
  def change
    # The WebAuthn user handle - a stable random id (not the DB id, per spec) tying a passkey
    # back to a user without leaking anything derivable about the account.
    add_column(:users, :webauthn_id, :string)

    create_table(:passkeys) do |t|
      t.references(:user, null: false, foreign_key: true)
      t.string(:external_id, null: false, index: { unique: true })
      t.text(:public_key, null: false)
      t.bigint(:sign_count, null: false, default: 0)
      t.string(:label, null: false, default: "")
      t.timestamp(:last_used_at)
      t.timestamps
    end
  end
end
