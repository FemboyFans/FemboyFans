# frozen_string_literal: true

require("test_helper")

module PostSets
  class VersionsControllerTest < ActionDispatch::IntegrationTest
    context("The post set versions controller") do
      setup do
        @user = create(:user, created_at: 2.weeks.ago)
        @set = create(:post_set, creator: @user)
        @set.update_with!(@user, is_public: true)
      end

      context("index action") do
        setup do
          @posts = create_list(:post, 4)
          @set = create(:post_set, creator: @user)
          @user2 = create(:user, created_at: 2.weeks.ago)
          @user3 = create(:user, created_at: 2.weeks.ago)

          @set.update_with!(@user2, post_ids: @posts.first(2).pluck(:id))
          @set.update_with!(@user3, post_ids: @posts.pluck(:id))

          @versions = @set.versions
        end

        should("list all versions") do
          get_auth(post_set_versions_path, @user)

          assert_response(:success)
          assert_select("#post-set-version-#{@versions[0].id}")
          assert_select("#post-set-version-#{@versions[1].id}")
          assert_select("#post-set-version-#{@versions[2].id}")
        end

        should("list all versions that match the search criteria") do
          get_auth(post_set_versions_path, @user, params: { search: { updater_id: @user2.id } })

          assert_response(:success)
          assert_select("#post-set-version-#{@versions[0].id}", false)
          assert_select("#post-set-version-#{@versions[1].id}")
          assert_select("#post-set-version-#{@versions[2].id}", false)
        end

        should("not include versions of a private set the viewer can't see") do
          private_set = create(:post_set, creator: create(:user, created_at: 2.weeks.ago))
          version = private_set.versions.first

          get_auth(post_set_versions_path, @user, params: { format: :json })

          assert_response(:success)
          assert_not_includes(response.parsed_body.pluck("id"), version.id)
        end

        should("include versions of a private set to its owner") do
          private_set = create(:post_set, creator: @user)
          version = private_set.versions.first

          get_auth(post_set_versions_path, @user, params: { format: :json })

          assert_response(:success)
          assert_includes(response.parsed_body.pluck("id"), version.id)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(post_set_versions_path)
          end
        end

        context("search parameters") do
          subject { post_set_versions_path }
          setup do
            PostSetVersion.delete_all
            PostSet.delete_all
            @updater = create(:user, created_at: 2.weeks.ago)
            @admin = create(:admin_user)
            @search_set = create(:post_set, creator: @updater, creator_ip_addr: "127.0.0.2", name: "foo", description: "bar", is_public: true)
            @search_version = @search_set.versions.first
          end

          asserts do
            search(:post_set_id).value { @search_set.id }.records { [@search_version] }
            search(:name_matches, "foo").records { [@search_version] }
            search(:description_matches, "bar").records { [@search_version] }
            search(:updater_id).value { @updater.id }.records { [@search_version] }
            search(:updater_name).value { @updater.name }.records { [@search_version] }
            search.shared.records { [@search_version] }
          end
        end
      end

      context("diff action") do
        setup { @set.update_with!(@user, name: "renamed_set") }

        should("render for a public set's version") do
          get_auth(diff_post_set_version_path(@set.versions.last), create(:user))

          assert_response(:success)
        end

        should("render for anonymous viewers of a public set's version") do
          get(diff_post_set_version_path(@set.versions.last))

          assert_response(:success)
        end

        should("not be visible to other users when the set is private") do
          private_set = create(:post_set, creator: @user)
          private_set.update_with!(@user, name: "renamed_private_set")

          get_auth(diff_post_set_version_path(private_set.versions.last), create(:user), params: { format: :json })

          assert_response(:forbidden)
        end

        should("be visible to the owner when the set is private") do
          private_set = create(:post_set, creator: @user)
          private_set.update_with!(@user, name: "renamed_private_set")

          get_auth(diff_post_set_version_path(private_set.versions.last), @user)

          assert_response(:success)
        end
      end

      context("undo action") do
        setup do
          @posts = create_list(:post, 2)
          @set = create(:post_set, creator: @user, post_ids: [@posts.first.id])
          @set.update_with!(@user, post_ids: [@posts.first.id, @posts.second.id])
        end

        should("work") do
          version = @set.versions.first

          assert_equal([@posts.first.id], version.post_ids)
          put_auth(undo_post_set_version_path(@set.versions.second), @user)
          @set.reload

          assert_equal([@posts.first.id], @set.post_ids)
        end

        should("not allow undoing version 1") do
          put_auth(undo_post_set_version_path(@set.versions.first), @user)

          assert_response(:bad_request)
        end

        should("not allow non-owners to undo") do
          put_auth(undo_post_set_version_path(@set.versions.second), create(:user), params: { format: :json })

          assert_response(:forbidden)
        end

        context("access control (not owner)") do
          asserts do
            access.gte(User::Levels::ADMIN).put { undo_post_set_version_path(@set.versions.second) }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.put { undo_post_set_version_path(@set.versions.second) }
          end
        end
      end
    end
  end
end
