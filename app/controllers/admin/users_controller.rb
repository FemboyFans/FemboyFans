# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    respond_to :html, :json

    def alt_list
      authorize(%i[admin user])
      offset = params[:page].to_i || 1
      offset -= 1
      offset = offset.clamp(0, 9999)
      offset *= 250
      @alts = User.connection.select_all(<<~SQL.squish)
        SELECT u1.id as u1id, u2.id as u2id
        FROM (SELECT * FROM users ORDER BY id DESC LIMIT 250 OFFSET #{offset}) u1
        INNER JOIN users u2 ON u1.last_ip_addr = u2.last_ip_addr AND u1.id != u2.id AND u2.last_logged_in_at > now() - interval '3 months'
        ORDER BY u1.id DESC, u2.last_logged_in_at DESC;
      SQL
      @alts = @alts.group_by { |i| i["u1id"] }.transform_values { |v| v.pluck("u2id") }
      @alts = { 3 => [3, 2], 2 => [3, 2], 9 => [9] }
      user_ids = @alts.flatten(2).uniq
      @users = User.where(id: user_ids).index_by(&:id)
      @alts = FemboyFans::Paginator::PaginatedArray.new(@alts.to_a, { pagination_mode: :numbered, records_per_page: 250, total_count: 9_999_999_999, current_page: params[:page].to_i, max_numbered_pages: 9999 })
      respond_with(@alts)
    end

    def edit
      authorize([:admin, User.find(params[:id])])
      @user = User.find(params[:id])
    end

    # TODO: redo this, remove the UserPromotion middleman and move strong parameters to pundit
    def update
      User.transaction do # rubocop:disable Metrics/BlockLength
        @user = authorize([:admin, User.find(params[:id])])
        raise(User::PrivilegeError) unless @user.can_admin_edit?(CurrentUser.user)
        @user.validate_email_format = true
        @user.is_admin_edit = true
        @user.update(user_params(CurrentUser.user))

        if CurrentUser.is_owner?
          @user.mark_verified! if params[:user][:verified].to_s.truthy?
          @user.mark_unverified! if params[:user][:verified].to_s.falsy?
        end
        @user.promote_to!(params[:user][:level] || @user.level, params[:user])

        old_username = @user.name
        desired_username = params[:user][:name]
        if old_username != desired_username && desired_username.present?
          change_request = UserNameChangeRequest.create(
            original_name:           @user.name,
            user_id:                 @user.id,
            desired_name:            desired_username,
            change_reason:           "Administrative change",
            skip_limited_validation: true,
          )
          if change_request.valid?
            change_request.approve!
            @user.log_name_change
          else
            @user.errors.add(:name, change_request.errors[:desired_name].join("; "))
          end
        end
        raise(ActiveRecord::Rollback) if @user.errors.any?
      end
      notice(@user.errors.any? ? "Update failed" : "User updated")
      respond_with(@user)
    end

    def edit_blacklist
      @user = authorize([:admin, User.find(params[:id])])
    end

    def update_blacklist
      @user = authorize([:admin, User.find(params[:id])])
      @user.is_admin_edit = true
      @user.update(params[:user].permit([:blacklisted_tags]))
      notice("Blacklist updated")
      respond_with(@user, status: 200)
    end

    def request_password_reset
      @user = authorize([:admin, User.find(params[:id])])
    end

    def password_reset
      @user = authorize([:admin, User.find(params[:id])])

      unless User.authenticate(CurrentUser.name, params[:admin][:password])
        return redirect_to(request_password_reset_admin_user_path(@user), notice: "Password wrong")
      end

      @user.update_columns(password_hash: "", bcrypt_password_hash: "*AC*") if params[:admin][:invalidate_old_password]&.truthy?

      @reset_key = UserPasswordResetNonce.create(user_id: @user.id)
    end

    private

    def user_params(user)
      # pparams = policy([:admin, User]).permitted_attributes_for_update
      pparams = %i[profile_about profile_artinfo base_upload_limit enable_privacy_mode]
      pparams << :email if user.is_owner?
      params.require(:user).slice(*pparams).permit(pparams)
    end
  end
end
