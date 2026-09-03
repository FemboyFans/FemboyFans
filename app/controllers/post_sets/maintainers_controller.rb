# frozen_string_literal: true

module PostSets
  class MaintainersController < ApplicationController
    respond_to(:html)
    respond_to(:js, except: %i[index])

    def index
      @invites = authorize(PostSetMaintainer).html_includes(request, :post_set)
                                             .visible(CurrentUser.user)
                                             .order(updated_at: :desc)
    end

    def create
      @set = PostSet.find(params[:post_set_id])
      authorize(@set, :add_maintainer?)
      @user = User.find_by_normalized_name(params[:username])
      if @user.nil?
        notice("User #{params[:username]} not found")
        respond_to do |format|
          format.html { redirect_to(maintainers_post_set_path(@set)) }
          format.json { render_expected_error(404, "User #{params[:username]} not found") }
        end
        return
      end
      @invite = PostSetMaintainer.new(post_set_id: @set.id, user_id: @user.id, status: "pending")
      @invite.validate

      if @invite.invalid?
        notice(@invite.errors.full_messages.join("; "))
        redirect_to(maintainers_post_set_path(@set))
        return
      end

      if RateLimiter.check_limit("set.invite.#{CurrentUser.user.id}", 5, 1.hour)
        notice("You must wait an hour before inviting more set maintainers")
      end

      PostSetMaintainer.where(user_id: @user.id, post_set_id: @set.id).destroy_all
      @invite.save

      if @invite.valid?
        RateLimiter.hit("set.invite.#{CurrentUser.user.id}", 1.hour)
        notice("#{@user.pretty_name} invited to be a maintainer")
      else
        notice(@invite.errors.full_messages.join("; "))
      end
      respond_with(@invite, location: maintainers_post_set_path(@set)) do |format|
        format.html { redirect_to(maintainers_post_set_path(@set)) }
      end
    end

    def destroy
      @maintainer = authorize(PostSetMaintainer.find(params[:id] || params[:post_set_maintainer][:id]), :cancel?)
      @set = authorize(@maintainer.post_set, :add_maintainer?)

      was_approved = @maintainer.status == "approved"
      @maintainer.cancel!
      PostSetVersion.queue(@set, CurrentUser.user.resolvable(CurrentUser.ip_addr)) if was_approved
      respond_with(@set)
    end

    def approve
      @maintainer = authorize(PostSetMaintainer.find(params[:id]))

      @maintainer.approve!
      PostSetVersion.queue(@maintainer.post_set, CurrentUser.user.resolvable(CurrentUser.ip_addr))
      notice("You are now a maintainer for the set")
      respond_with(@maintainer, location: post_set_maintainers_path) do |format|
        format.html { redirect_to(post_set_maintainers_path) }
      end
    end

    def deny
      @maintainer = authorize(PostSetMaintainer.find(params[:id]))

      was_approved = @maintainer.status == "approved"
      @maintainer.deny!
      PostSetVersion.queue(@maintainer.post_set, CurrentUser.user.resolvable(CurrentUser.ip_addr)) if was_approved
      notice("You have declined the set maintainer invite")
      respond_with(@maintainer, location: post_set_maintainers_path) do |format|
        format.html { redirect_to(post_set_maintainers_path) }
      end
    end

    def block
      @maintainer = authorize(PostSetMaintainer.find(params[:id]))

      was_approved = @maintainer.status == "approved"
      @maintainer.block!
      PostSetVersion.queue(@maintainer.post_set, CurrentUser.user.resolvable(CurrentUser.ip_addr)) if was_approved
      notice("You will not receive further invites for this set")
      respond_with(@maintainer, location: post_set_maintainers_path) do |format|
        format.html { redirect_to(post_set_maintainers_path) }
      end
    end
  end
end
