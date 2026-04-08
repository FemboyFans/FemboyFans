# frozen_string_literal: true

require("test_helper")

class PostSetsControllerTest < ActionDispatch::IntegrationTest
  context("The post sets controller") do
    setup do
      @user = create(:user)
      @other_user = create(:user)
      @mod = create(:moderator_user)
      @post = create(:post)
      @post_set = create(:post_set, creator: @user, is_public: true)
    end

    context("index action") do
      should("render") do
        get(post_sets_path)
        assert_response(:success)
      end

      should("filter by post_id") do
        get_auth(post_sets_path, @user, params: { search: { post_id: @post.id } })
        assert_response(:success)
      end

      should("filter by maintainer_id") do
        get_auth(post_sets_path, @user, params: { search: { maintainer_id: @user.id } })
        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(post_sets_path, user) }
      end
    end

    context("show action") do
      should("render for a public set") do
        get(post_set_path(@post_set))
        assert_response(:success)
      end

      should("restrict access to private sets") do
        @private_set = create(:post_set, creator: @user, is_public: false)
        get_auth(post_set_path(@private_set), @other_user)
        assert_response(:forbidden)
      end

      should("allow owner to view private set") do
        @private_set = create(:post_set, creator: @user, is_public: false)
        get_auth(post_set_path(@private_set), @user)
        assert_response(:success)
      end
    end

    context("new action") do
      should("render") do
        get_auth(new_post_set_path, @user)
        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER) { |user| get_auth(new_post_set_path, user) }
      end
    end

    context("create action") do
      should("work") do
        assert_difference("PostSet.count", 1) do
          post_auth(post_sets_path, @user, params: { post_set: { name: "my test set", shortname: "my_test_set" } })
        end
        assert_redirected_to(post_set_path(PostSet.last))
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| post_auth(post_sets_path, user, params: { post_set: { name: "set_#{SecureRandom.hex(4)}", shortname: "set_#{SecureRandom.hex(4)}" } }) }
      end
    end

    context("edit action") do
      should("render") do
        get_auth(edit_post_set_path(@post_set), @user)
        assert_response(:success)
      end

      should("deny access to non-owner") do
        get_auth(edit_post_set_path(@post_set), @other_user)
        assert_response(:forbidden)
      end
    end

    context("update action") do
      should("work") do
        put_auth(post_set_path(@post_set), @user, params: { post_set: { name: "updated name", shortname: "updated_shortname" } })
        @post_set.reload
        assert_equal("updated name", @post_set.name)
      end

      should("deny access to non-owner") do
        put_auth(post_set_path(@post_set), @other_user, params: { post_set: { name: "hacked" } })
        assert_response(:forbidden)
      end
    end

    context("destroy action") do
      should("work") do
        assert_difference("PostSet.count", -1) do
          delete_auth(post_set_path(@post_set), @user)
        end
      end

      should("deny access to non-owner") do
        assert_no_difference("PostSet.count") do
          delete_auth(post_set_path(@post_set), @other_user)
          assert_response(:forbidden)
        end
      end
    end

    context("post_list action") do
      should("render") do
        get_auth(post_list_post_set_path(@post_set), @user)
        assert_response(:success)
      end

      should("restrict access to private sets") do
        @private_set = create(:post_set, creator: @user, is_public: false)
        get_auth(post_list_post_set_path(@private_set), @other_user)
        assert_response(:forbidden)
      end
    end

    context("maintainers action") do
      should("render") do
        get_auth(maintainers_post_set_path(@post_set), @user)
        assert_response(:success)
      end
    end

    context("for_select action") do
      should("work") do
        get_auth(for_select_post_sets_path, @user, params: { format: :json })
        assert_response(:success)
        json = response.parsed_body
        assert(json.key?("Owned"))
        assert(json.key?("Maintained"))
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER) { |user| get_auth(for_select_post_sets_path, user, params: { format: :json }) }
      end
    end

    context("add_posts action") do
      should("work") do
        post_auth(add_posts_post_set_path(@post_set), @user, params: { post_set: { post_ids: [@post.id] }, format: :json })
        assert_response(:success)
        assert_includes(@post_set.reload.post_ids, @post.id)
      end

      should("deny access to non-owner") do
        post_auth(add_posts_post_set_path(@post_set), @other_user, params: { post_set: { post_ids: [@post.id] } })
        assert_response(:forbidden)
      end
    end

    context("remove_posts action") do
      setup do
        @post_set.add([@post.id])
        @post_set.save
      end

      should("work") do
        post_auth(remove_posts_post_set_path(@post_set), @user, params: { post_set: { post_ids: [@post.id] }, format: :json })
        assert_response(:success)
        assert_not_includes(@post_set.reload.post_ids, @post.id)
      end

      should("deny access to non-owner") do
        post_auth(remove_posts_post_set_path(@post_set), @other_user, params: { post_set: { post_ids: [@post.id] } })
        assert_response(:forbidden)
      end
    end
  end
end
