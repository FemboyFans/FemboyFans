# frozen_string_literal: true

module Posts
  class FlagsController < ApplicationController
    respond_to(:html, :json)

    def index
      @search_params = search_params(PostFlag)
      @post_flags = authorize(PostFlag).html_includes(request, :creator, post: %i[flags uploader approver])
                                       .search_current(@search_params)
                                       .paginate(params[:page], limit: params[:limit])
      respond_with(@post_flags)
    end

    def show
      @post_flag = authorize(PostFlag.find(params[:id]))
      respond_with(@post_flag) do |format|
        format.html { redirect_to(post_flags_path(search: { id: @post_flag.id })) }
      end
    end

    def new
      @post_flag = authorize(PostFlag.new_with_current(:creator, permitted_attributes(PostFlag)))
      @post = Post.find(params[:post_flag].try(:[], :post_id))
      respond_with(@post_flag)
    end

    def create
      @post_flag = authorize(PostFlag.new_with_current(:creator, permitted_attributes(PostFlag)))
      @post_flag.save
      respond_with(@post_flag) do |format|
        format.html do
          if @post_flag.errors.empty?
            redirect_to(post_path(id: @post_flag.post_id))
          else
            @post = Post.find(params[:post_flag][:post_id])
            respond_with(@post_flag)
          end
        end
      end
    end

    def destroy
      @post = Post.find(params[:post_id])
      authorize(PostFlag)
      @post.unflag!(CurrentUser.user)
      if params[:approval] == "approve" && @post.is_approvable?(CurrentUser.user)
        @post.approve!(CurrentUser.user)
      end
      respond_with(nil)
    end
  end
end
