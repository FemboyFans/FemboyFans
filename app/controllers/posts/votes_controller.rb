# frozen_string_literal: true

module Posts
  class VotesController < ApplicationController
    respond_to(:html, :json)
    before_action(:ensure_lockdown_disabled)
    skip_before_action(:api_check)

    def index
      @post_votes = authorize(PostVote).html_includes(request, :user)
                                       .search_current(search_params(PostVote))
                                       .paginate(params[:page], limit: 100)
      respond_with(@post_votes)
    end

    def create
      authorize(PostVote)
      @post = Post.find(params[:post_id])
      @post_vote, @status = VoteManager::Posts.vote!(post: @post, user: CurrentUser.user, ip_addr: CurrentUser.ip_addr, score: params[:score])
      if @status == :need_unvote && !params[:no_unvote].to_s.truthy?
        VoteManager::Posts.unvote!(post: @post, user: CurrentUser.user)
      end
      respond_to do |format|
        format.html { render_vote_response }
        format.json { render(json: { score: @post.score, up: @post.up_score, down: @post.down_score, our_score: @status == :need_unvote ? 0 : @post_vote.score, is_locked: @post_vote.is_locked? }) }
      end
    rescue UserVote::Error, ActiveRecord::RecordInvalid => e
      render_expected_error(422, e)
    end

    def destroy
      authorize(PostVote)
      @post = Post.find(params[:post_id])
      VoteManager::Posts.unvote!(post: @post, user: CurrentUser.user)
    rescue UserVote::Error => e
      render_expected_error(422, e)
    end

    def lock
      authorize(PostVote)
      ids = params[:ids].split(",")

      ids.each do |id|
        VoteManager::Posts.lock!(id, CurrentUser.user)
      end
    end

    def delete
      authorize(PostVote)
      ids = params[:ids].split(",")

      ids.each do |id|
        VoteManager::Posts.admin_unvote!(id, CurrentUser.user)
      end
    end

    private

    # The show page has a single static vote frame; the index thumbnail grid re-renders the whole
    # thumbnail per post so its score/fav-count/vote-highlighting all stay in sync after voting.
    def render_vote_response
      if turbo_frame_request_id == "post-preview-#{@post.id}"
        render(html: PostsDecorator.new(@post).preview_html(tags: params[:tags], show_cropped: true, stats: true), layout: false)
      else
        render(partial: "posts/partials/show/vote", locals: { post: @post }, layout: false)
      end
    end

    def ensure_lockdown_disabled
      access_denied if Security::Lockdown.votes_disabled? && !CurrentUser.user.is_staff?
    end
  end
end
