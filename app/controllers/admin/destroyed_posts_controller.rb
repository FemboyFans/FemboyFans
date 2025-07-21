# frozen_string_literal: true

module Admin
  class DestroyedPostsController < ApplicationController
    respond_to(:html)

    def index
      @destroyed_posts = authorize(DestroyedPost).html_includes(request, :destroyer, :uploader)
                                                 .search_current(search_params(DestroyedPost))
                                                 .paginate(params[:page], limit: params[:limit])
    end

    def show
      authorize(DestroyedPost)
      redirect_to(admin_destroyed_posts_path(search: { post_id: params[:id] }))
    end

    def update
      @destroyed_post = authorize(DestroyedPost.find_by!(post_id: params[:id]))
      @destroyed_post.update_with_current(:updater, permitted_attributes(@destroyed_post))
      flash[:notice] = @destroyed_post.notify? ? "Re-uploads of that post will now notify admins" : "Re-uploads of that post will no longer notify admins"
      redirect_to(admin_destroyed_posts_path)
    end
  end
end
