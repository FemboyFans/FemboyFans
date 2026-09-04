# frozen_string_literal: true

module Forums
  module Posts
    class VotesController < ApplicationController
      respond_to(:html, only: %i[index])
      respond_to(:json)
      before_action(:load_forum_post, except: %i[index delete])
      before_action(:validate_forum_post, except: %i[index delete])
      before_action(:validate_no_vote_on_own_post, only: %i[create])
      before_action(:ensure_lockdown_disabled)

      def index
        @forum_post_votes = authorize(ForumPostVote).html_includes(request, :user, forum_post: %i[creator])
                                                    .search_current(search_params(ForumPostVote))
                                                    .paginate(params[:page], limit: 100)
        respond_with(@forum_post_votes)
      end

      def create
        authorize(@forum_post, policy_class: ForumPostVotePolicy)
        raise(User::PrivilegeError, "You are not allowed to vote on tag change requests.") if @forum_post.is_aibur? && CurrentUser.user.no_aibur_voting?
        raise(User::PrivilegeError, "You cannot vote on completed tag change requests.") if @forum_post.is_aibur? && !@forum_post.tag_change_request.is_pending?
        @forum_post_vote = VoteManager::ForumPosts.vote!(user: CurrentUser.user, ip_addr: CurrentUser.ip_addr, forum_post: @forum_post, score: params[:score])
        respond_with(@forum_post_vote) do |fmt|
          fmt.json { render(json: @forum_post_vote.as_json.merge(overview_html: render_vote_overview), code: 201) }
        end
      end

      def destroy
        authorize(@forum_post, policy_class: ForumPostVotePolicy)
        raise(User::PrivilegeError, "You cannot unvote on completed tag change requests.") if @forum_post.is_aibur? && !@forum_post.tag_change_request.is_pending?
        VoteManager::ForumPosts.unvote!(forum_post: @forum_post, user: CurrentUser.user)
        render(json: { overview_html: render_vote_overview })
      rescue UserVote::Error => e
        render_expected_error(422, e)
      end

      def delete
        authorize(ForumPostVote)
        ids = params[:ids].split(",")

        ids.each do |id|
          VoteManager::ForumPosts.admin_unvote!(id, CurrentUser.user)
        end
      end

      private

      # The vote overview (up/meh/down counts and percentage) is a cached column, updated via an
      # after_commit callback on ForumPostVote - reload to pick that up before re-rendering it.
      def render_vote_overview
        @forum_post.reload
        render_to_string(partial: "forums/posts/votes/overview", locals: { votes: @forum_post.votes, forum_post: @forum_post }, formats: [:html])
      end

      def load_forum_post
        @forum_post = ForumPost.find(params[:forum_post_id])
      end

      def validate_forum_post
        raise(User::PrivilegeError) unless @forum_post.visible?(CurrentUser.user)
        render_expected_error(400, "Forum post does not allow votes.") unless @forum_post.has_voting?
      end

      def validate_no_vote_on_own_post
        raise(User::PrivilegeError, "You cannot vote on your own requests") if @forum_post.creator == CurrentUser.user
      end

      def ensure_lockdown_disabled
        access_denied if Security::Lockdown.votes_disabled? && !CurrentUser.user.is_staff?
      end
    end
  end
end
