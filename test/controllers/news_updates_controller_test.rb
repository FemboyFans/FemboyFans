# frozen_string_literal: true

require("test_helper")

class NewsUpdatesControllerTest < ActionDispatch::IntegrationTest
  context("the news updates controller") do
    setup do
      @admin = create(:admin_user)
      @news_update = create(:news_update)
    end

    context("index action") do
      should("render") do
        get_auth(news_updates_path, @admin)
        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(news_updates_path, user) }
      end
    end

    context("new action") do
      should("render") do
        get_auth(new_news_update_path, @admin)
        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN) { |user| get_auth(new_news_update_path, user) }
      end
    end

    context("edit action") do
      should("render") do
        get_auth(edit_news_update_path(@news_update), @admin)
        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN) { |user| get_auth(edit_news_update_path(@news_update), user) }
      end
    end

    context("update action") do
      should("work") do
        put_auth(news_update_path(@news_update), @admin, params: { news_update: { message: "zzz" } })
        assert_redirected_to(news_updates_path)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| put_auth(news_update_path(@news_update), user, params: { news_update: { message: "zzz" } }) }
      end
    end

    context("create action") do
      should("work") do
        assert_difference("NewsUpdate.count") do
          post_auth(news_updates_path, @admin, params: { news_update: { message: "zzz" } })
        end
        assert_redirected_to(news_updates_path)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| post_auth(news_updates_path, user, params: { news_update: { message: "zzz" } }) }
      end
    end

    context("destroy action") do
      should("work") do
        assert_difference("NewsUpdate.count", -1) do
          delete_auth(news_update_path(@news_update), @admin)
        end
        assert_redirected_to(news_updates_path)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| delete_auth(news_update_path(create(:news_update)), user) }
      end
    end
  end
end
