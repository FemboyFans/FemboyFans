# frozen_string_literal: true

module Posts
  class DisapprovalsController < ApplicationController
    skip_before_action(:api_check)
    respond_to(:html, :json)

    def index
      @post_disapprovals = authorize(PostDisapproval).html_includes(request, :user)
                                                     .search_current(search_params(PostDisapproval))
                                                     .paginate(params[:page], limit: params[:limit])
      respond_with(@post_disapprovals)
    end

    def create
      authorize(PostDisapproval)
      pd_params = permitted_attributes(PostDisapproval)
      @post_disapproval = PostDisapproval.find_by(user_id: CurrentUser.user.id, post_id: pd_params[:post_id])
      @post_disapproval ||= PostDisapproval.new_with_current(:user, pd_params)
      @post_disapproval.reason = pd_params[:reason] || ""
      @post_disapproval.message = pd_params[:message] || ""
      @post_disapproval.save!
      respond_with do |format|
        format.html { redirect_to(post_path(id: pd_params[:post_id])) }
        format.json { render(json: @post_disapproval) }
      end
    rescue ActiveRecord::RecordInvalid => e
      render_expected_error(422, e.message)
    end
  end
end
