# frozen_string_literal: true

module Posts
  class ApprovalsController < ApplicationController
    skip_before_action(:api_check, except: %i[index])
    respond_to(:html, :json)

    def index
      @post_approvals = authorize(PostApproval).html_includes(request, :post, :user)
                                               .search_current(search_params(PostApproval))
                                               .paginate(params[:page], limit: params[:limit])
      respond_with(@post_approvals)
    end

    def create
      @post = authorize(Post.find(params[:post_id]), policy_class: PostApprovalPolicy)
      if @post.is_approvable?(CurrentUser.user)
        @post.approve!(CurrentUser.user)
        respond_to do |format|
          format.json
        end
      elsif @post.approver.present?
        notice("Post is already approved")
        render_expected_error(400, "Post is already approved") if request.format.json?
      else
        notice("You can't approve this post")
        render_expected_error(400, "You can't approve this post") if request.format.json?
      end
    end

    def destroy
      @post = authorize(Post.find(params[:id]), policy_class: PostApprovalPolicy)
      if @post.is_unapprovable?(CurrentUser.user)
        @post.unapprove!(CurrentUser.user)
        respond_with(nil)
      else
        flash[:notice] = "You can't unapprove this post"
        render_expected_error(400, "You can't unapprove this post") if request.format.json?
      end
    end
  end
end
