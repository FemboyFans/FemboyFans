# frozen_string_literal: true

module Users
  class PasskeysController < ApplicationController
    respond_to(:html)
    before_action(:requires_reauthentication)

    def index
      @user = authorize(CurrentUser.user, policy_class: PasskeyPolicy)
      @passkeys = @user.passkeys
    end

    def new
      @user = authorize(CurrentUser.user, policy_class: PasskeyPolicy)
      @registration_options, @registration_signed_challenge = Passkey.options_for_registration(@user)
    end

    def create
      @user = authorize(CurrentUser.user, policy_class: PasskeyPolicy)
      credential = JSON.parse(params.dig(:passkey, :credential).presence || "null")
      passkey = credential && @user.create_passkey!(credential, params.dig(:passkey, :signed_challenge), request, label: params.dig(:passkey, :label))

      if passkey
        notice("Passkey registered")
        respond_with(passkey, location: user_passkeys_path)
      else
        notice("Couldn't verify passkey, please try again")
        respond_with(passkey, location: new_user_passkey_path)
      end
    rescue JSON::ParserError
      notice("Couldn't verify passkey, please try again")
      redirect_to(new_user_passkey_path)
    end

    def destroy
      @passkey = authorize(Passkey.find(params[:id]))
      CurrentUser.user.destroy_passkey!(@passkey, request)
      notice("Passkey removed")
      respond_with(@passkey, location: user_passkeys_path)
    end
  end
end
