# frozen_string_literal: true

require "test_helper"

class WikiPagesControllerTest < ActionDispatch::IntegrationTest
  context "The wiki pages controller" do
    setup do
      @user = create(:user)
      @mod = create(:moderator_user)
      as(@user) do
        @wiki_page = create(:wiki_page)
      end
    end

    context "index action" do
      setup do
        as(@user) do
          @wiki_page_abc = create(:wiki_page, title: "abc")
          @wiki_page_def = create(:wiki_page, title: "def")
        end
      end

      should "list all wiki_pages" do
        get wiki_pages_path
        assert_response :success
      end

      should "list all wiki_pages (with search)" do
        get wiki_pages_path, params: { search: { title: "abc" } }
        assert_redirected_to(wiki_page_path(@wiki_page_abc))
      end

      should "list wiki_pages without tags with order=post_count" do
        get wiki_pages_path, params: { search: { title: "abc", order: "post_count" } }
        assert_redirected_to(wiki_page_path(@wiki_page_abc))
      end

      should "restrict access" do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth wiki_pages_path, user }
      end
    end

    context "show action" do
      should "render" do
        get wiki_page_path(@wiki_page)
        assert_response :success
      end

      should "render for a title" do
        get wiki_page_path(id: @wiki_page.title)
        assert_response :success
      end

      should "redirect html requests for a nonexistent title" do
        get wiki_page_path("what")
        assert_redirected_to(show_or_new_wiki_pages_path(title: "what"))
      end

      should "return 404 to api requests for a nonexistent title" do
        get wiki_page_path("what"), as: :json
        assert_response 404
      end

      should "render for a negated tag" do
        as(@user) do
          @wiki_page.update(title: "-aaa")
        end
        get wiki_page_path(@wiki_page)
        assert_response :success
      end

      should "restrict access" do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth wiki_page_path(@wiki_page), user }
      end
    end

    context "show_or_new action" do
      should "redirect when given a title" do
        get show_or_new_wiki_pages_path, params: { title: @wiki_page.title }
        assert_redirected_to(@wiki_page)
      end

      should "render when given a nonexistent title" do
        get show_or_new_wiki_pages_path, params: { title: "what" }
        assert_response :success
      end

      should "restrict access" do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth show_or_new_wiki_pages_path, user, params: { title: "gay" } }
      end
    end

    context "new action" do
      should "render" do
        get_auth new_wiki_page_path, @mod, params: { wiki_page: { title: "test" } }
        assert_response :success
      end

      should "restrict access" do
        assert_access(User::Levels::MEMBER) { |user| get_auth new_wiki_page_path, user }
      end
    end

    context "edit action" do
      should "render" do
        get_auth wiki_page_path(@wiki_page), @mod
        assert_response :success
      end

      should "restrict access" do
        assert_access(User::Levels::MEMBER) { |user| get_auth edit_wiki_page_path(@wiki_page), user }
      end
    end

    context "create action" do
      should "create a wiki_page" do
        assert_difference("WikiPage.count", 1) do
          post_auth wiki_pages_path, @user, params: { wiki_page: { title: "abc", body: "abc" } }
        end
      end

      should "restrict access" do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| post_auth wiki_pages_path, user, params: { wiki_page: { title: SecureRandom.hex(6), body: SecureRandom.hex(6) } } }
      end
    end

    context "update action" do
      setup do
        as(@user) do
          @tag = create(:tag, name: @wiki_page.title, post_count: 42)
        end
      end

      should "update a wiki_page" do
        put_auth wiki_page_path(@wiki_page), @user, params: { wiki_page: { body: "xyz" } }
        @wiki_page.reload
        assert_equal("xyz", @wiki_page.body)
      end

      should "not rename a wiki page with a non-empty tag" do
        ogtitle = @wiki_page.title
        put_auth wiki_page_path(@wiki_page), @user, params: { wiki_page: { title: "bar" } }
        assert_equal(ogtitle, @wiki_page.reload.title)
      end

      should "rename a wiki page with a non-empty tag if the check is skipped" do
        put_auth wiki_page_path(@wiki_page), @mod, params: { wiki_page: { title: "bar", skip_post_count_rename_check: "1" } }
        assert_equal("bar", @wiki_page.reload.title)
      end

      should "restrict access" do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| put_auth wiki_page_path(@wiki_page), user, params: { wiki_page: { body: SecureRandom.hex(6) } } }
      end
    end

    context "destroy action" do
      setup do
        as(@user) do
          @wiki_page = create(:wiki_page)
        end
      end

      should "destroy a wiki_page" do
        delete_auth wiki_page_path(@wiki_page), create(:admin_user)
        assert_raises(ActiveRecord::RecordNotFound) { @wiki_page.reload }
      end

      should "restrict access" do
        skip("Doesn't work due to properties attempting to be set after the record is destroyed")
        as(@user) { @wiki_pages = create_list(:wiki_page, User::Levels.constants.length) }
        assert_access(User::Levels::ADMIN) { |user| delete_auth wiki_page_path(@wiki_pages.shift), user }
      end
    end

    context "revert action" do
      setup do
        as(@user) do
          @wiki_page = create(:wiki_page, body: "1")
          travel_to(1.day.from_now) do
            @wiki_page.update(body: "1 2")
          end
          travel_to(2.days.from_now) do
            @wiki_page.update(body: "1 2 3")
          end
        end
      end

      should "revert to a previous version" do
        version = @wiki_page.versions.first
        assert_equal("1", version.body)
        put_auth revert_wiki_page_path(@wiki_page), @user, params: { version_id: version.id }
        @wiki_page.reload
        assert_equal("1", @wiki_page.body)
      end

      should "not allow reverting to a previous version of another wiki page" do
        as(@user) do
          @wiki_page2 = create(:wiki_page)
        end

        put_auth revert_wiki_page_path(@wiki_page), @user, params: { version_id: @wiki_page2.versions.first.id }
        @wiki_page.reload

        assert_not_equal(@wiki_page.body, @wiki_page2.body)
        assert_response :missing
      end

      should "restrict access" do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| put_auth revert_wiki_page_path(@wiki_page), user, params: { version_id: @wiki_page.versions.first.id } }
      end
    end
  end
end
