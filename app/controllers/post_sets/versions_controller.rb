# frozen_string_literal: true

module PostSets
  class VersionsController < ApplicationController
    respond_to(:html, :json)

    def index
      if (post_set_id = params.dig(:search, :post_set_id)).present?
        @post_set = PostSet.find_by(id: post_set_id)
      end

      @post_set_versions = authorize(PostSetVersion).html_includes(request, :updater)
                                                    .search_current(search_params(PostSetVersion))
                                                    .paginate(params[:page], limit: params[:limit])
      respond_with(@post_set_versions)
    end

    def diff
      @post_set_version = authorize(PostSetVersion.find(params[:id]))
    end

    def undo
      @post_set_version = authorize(PostSetVersion.find(params[:id]))
      @post_set_version.undo!(CurrentUser.user)

      text = ""
      if @post_set_version.errors.any?
        text += @post_set_version.errors.full_messages.join(", ")
      elsif @post_set_version.post_set.errors.any?
        text += "; " if text.present?
        text += @post_set_version.post_set.errors.full_messages.join(", ")
      end

      return render_expected_error(422, text) if text.present?
      notice("Post set version undone")
      respond_with(@post_set_version) do |format|
        format.html { redirect_back_or_to(post_set_versions_path) }
      end
    end
  end
end
