# frozen_string_literal: true

require("test_helper")

class ThumbnailFrameProbeTest < ActionDispatch::IntegrationTest
  resets_post_index!

  setup do
    @user = create(:user)
    @post = create(:post)
    Post.document_store.refresh_index!
  end

  test("index thumbnail renders a post-preview turbo frame") do
    get_auth(posts_path, @user)
    assert_response(:success)
    assert_select("article#post_#{@post.id} turbo-frame#post-preview-#{@post.id}")
    assert_select("article#post_#{@post.id} turbo-frame#post-preview-#{@post.id} #vote-buttons")
    assert_select("article#post_#{@post.id} turbo-frame#post-preview-#{@post.id} .desc .post-score")
  end

  test("voting via the thumbnail frame re-renders the whole thumbnail with updated score") do
    post_auth(post_votes_path(post_id: @post.id), @user, params: { score: 1 }, headers: { "Turbo-Frame" => "post-preview-#{@post.id}" })
    assert_response(:success)
    assert_select("turbo-frame#post-preview-#{@post.id}")
    assert_select(".post-score-score-#{@post.id}", text: "1")
    assert_select("button.vote-button.vote-up.score-positive")
  end

  test("favoriting via the thumbnail frame re-renders the whole thumbnail with updated fav count") do
    post_auth(favorite_post_path(@post), @user, headers: { "Turbo-Frame" => "post-preview-#{@post.id}" })
    assert_response(:success)
    assert_select("turbo-frame#post-preview-#{@post.id}")
    assert_select(".post-score-faves-faves-#{@post.id}", text: "1")
    assert_select("span.post-favorite-#{@post.id}.is-favorited")
  end
end
