# frozen_string_literal: true

require("test_helper")

module PostSets
  class MaintainersControllerTest < ActionDispatch::IntegrationTest
    context("The post set maintainers controller") do
      setup do
        @owner = create(:user, created_at: 1.month.ago)
        @maintainer = create(:user, created_at: 1.month.ago)
        @set = create(:post_set, creator: @owner)
        @set.update_with!(@owner, is_public: true)
      end

      context("approve action") do
        setup { @invite = PostSetMaintainer.create!(post_set: @set, user: @maintainer, status: "pending") }

        should("create a set version recording the new maintainer") do
          assert_difference("@set.versions.count", 1) do
            get_auth(approve_post_set_maintainer_path(@invite), @maintainer)
          end

          assert_equal([@maintainer.id], @set.versions.last.added_maintainer_ids)
        end
      end

      context("deny action") do
        context("declining a pending invite") do
          setup { @invite = PostSetMaintainer.create!(post_set: @set, user: @maintainer, status: "pending") }

          should("not create a set version") do
            assert_no_difference("@set.versions.count") do
              get_auth(deny_post_set_maintainer_path(@invite), @maintainer)
            end
          end
        end

        context("removing themselves as an approved maintainer") do
          setup do
            @invite = PostSetMaintainer.create!(post_set: @set, user: @maintainer, status: "pending")
            get_auth(approve_post_set_maintainer_path(@invite), @maintainer)
            @invite.reload
          end

          should("create a set version recording the removal") do
            assert_difference("@set.versions.count", 1) do
              get_auth(deny_post_set_maintainer_path(@invite), @maintainer)
            end

            assert_equal([@maintainer.id], @set.versions.last.removed_maintainer_ids)
          end
        end
      end

      context("block action") do
        setup do
          @invite = PostSetMaintainer.create!(post_set: @set, user: @maintainer, status: "pending")
          get_auth(approve_post_set_maintainer_path(@invite), @maintainer)
          @invite.reload
        end

        should("create a set version recording the removal") do
          assert_difference("@set.versions.count", 1) do
            get_auth(block_post_set_maintainer_path(@invite), @maintainer)
          end

          assert_equal([@maintainer.id], @set.versions.last.removed_maintainer_ids)
        end
      end

      context("destroy action") do
        context("cancelling a pending invite") do
          setup { @invite = PostSetMaintainer.create!(post_set: @set, user: @maintainer, status: "pending") }

          should("not create a set version") do
            assert_no_difference("@set.versions.count") do
              delete_auth(post_set_maintainer_path(@invite), @owner)
            end
          end
        end

        context("removing an approved maintainer") do
          setup do
            @invite = PostSetMaintainer.create!(post_set: @set, user: @maintainer, status: "pending")
            get_auth(approve_post_set_maintainer_path(@invite), @maintainer)
            @invite.reload
          end

          should("create a set version recording the removal") do
            assert_difference("@set.versions.count", 1) do
              delete_auth(post_set_maintainer_path(@invite), @owner)
            end

            assert_equal([@maintainer.id], @set.versions.last.removed_maintainer_ids)
          end
        end
      end
    end
  end
end
