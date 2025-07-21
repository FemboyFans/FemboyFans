# frozen_string_literal: true

require("test_helper")

module Tags
  class VersionsControllerTest < ActionDispatch::IntegrationTest
    context("The tag versions controller") do
      setup do
        @user = create(:user)
        @user2 = create(:user)
        @user3 = create(:user)
      end

      context("index action") do
        setup do
          @tag = create(:tag, creator: @user)
          @tag.update_with(@user2, category: TagCategory.copyright)
          @tag.update_with(@user3, category: TagCategory.artist)

          @versions = @tag.versions
        end

        should("list all versions") do
          get(tag_versions_path)
          assert_response(:success)
          assert_select("#tag-version-#{@versions[0].id}")
          assert_select("#tag-version-#{@versions[1].id}")
          assert_select("#tag-version-#{@versions[2].id}")
        end

        should("list all versions that match the search criteria") do
          get(tag_versions_path, params: { search: { updater_id: @user2.id } })
          assert_response(:success)
          assert_select("#tag-version-#{@versions[0].id}", false)
          assert_select("#tag-version-#{@versions[1].id}")
          assert_select("#tag-version-#{@versions[2].id}", false)
        end

        should("restrict access") do
          assert_access(User::Levels::ANONYMOUS) { |user| get_auth(tag_versions_path, user) }
        end
      end
    end
  end
end
