# frozen_string_literal: true

require("test_helper")

module Rules
  class CategoriesControllerTest < ActionDispatch::IntegrationTest
    context("The rule categories controller") do
      setup do
        @admin = create(:admin_user)
        @user = create(:user)
        CurrentUser.user = @admin
        @category = create(:rule_category)
      end

      context("new action") do
        should("render") do
          get_auth(new_rule_category_path, @admin)
          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN) { |user| get_auth(new_rule_category_path, user) }
        end
      end

      context("edit action") do
        should("render") do
          get_auth(edit_rule_category_path(@category), @admin)
          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN) { |user| get_auth(edit_rule_category_path(@category), user) }
        end
      end

      context("create action") do
        should("create a new category") do
          assert_difference("RuleCategory.count", 1) do
            post_auth(rule_categories_path, @admin, params: { rule_category: { name: "blah" } })
          end
        end

        should("create a modaction") do
          assert_difference("ModAction.count", 1) do
            post_auth(rule_categories_path, @admin, params: { rule_category: { name: "blah" } })
          end

          mod_action = ModAction.last
          assert_equal("rule_category_create", mod_action.action)
          assert_equal(RuleCategory.last, mod_action.subject)
          assert_equal("blah", mod_action.name)
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| post_auth(rule_categories_path, user, params: { rule_category: { name: SecureRandom.hex(6) } }) }
        end
      end

      context("update action") do
        should("update the category") do
          put_auth(rule_category_path(@category), @admin, params: { rule_category: { name: "xxx" } })
          assert_redirected_to(rules_path)
        end

        should("create a modaction") do
          old = @category.name
          assert_difference("ModAction.count", 1) do
            put_auth(rule_category_path(@category), @admin, params: { rule_category: { name: "xxx" } })
          end

          mod_action = ModAction.last
          assert_equal("rule_category_update", mod_action.action)
          assert_equal(@category, mod_action.subject)
          assert_equal("xxx", mod_action.name)
          assert_equal(old, mod_action.old_name)
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| put_auth(rule_category_path(@category), user, params: { rule_category: { name: SecureRandom.hex(6) } }) }
        end
      end

      context("destroy action") do
        should("delete the category") do
          delete_auth(rule_category_path(@category), @admin)
          assert_redirected_to(rules_path)
          assert_raise(ActiveRecord::RecordNotFound) { @category.reload }
        end

        should("create a modaction") do
          assert_difference("ModAction.count", 1) do
            delete_auth(rule_category_path(@category), @admin)
          end

          mod_action = ModAction.last
          assert_equal("rule_category_delete", mod_action.action)
          assert_equal(@category.id, mod_action.subject_id)
          assert_equal("RuleCategory", mod_action.subject_type)
          assert_equal(@category.name, mod_action.name)
        end

        context("on a category with rules") do
          setup do
            @rule = create(:rule, category: @category)
          end

          should("delete the category and rules") do
            delete_auth(rule_category_path(@category), @admin)
            assert_redirected_to(rules_path)
            assert_raise(ActiveRecord::RecordNotFound) { @category.reload }
            assert_raise(ActiveRecord::RecordNotFound) { @rule.reload }
          end

          should("create modactions") do
            assert_difference("ModAction.count", 2) do
              delete_auth(rule_category_path(@category), @admin)
            end

            rule_action, category_action = ModAction.last(2)
            assert_equal("rule_delete", rule_action.action)
            assert_equal(@rule.id, rule_action.subject_id)
            assert_equal("Rule", rule_action.subject_type)
            assert_equal(@rule.name, rule_action.name)

            assert_equal("rule_category_delete", category_action.action)
            assert_equal(@category.id, category_action.subject_id)
            assert_equal("RuleCategory", category_action.subject_type)
            assert_equal(@category.name, category_action.name)
          end
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| delete_auth(rule_category_path(create(:rule_category)), user) }
        end
      end
    end
  end
end
