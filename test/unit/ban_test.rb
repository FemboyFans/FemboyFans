# frozen_string_literal: true

require("test_helper")

class BanTest < ActiveSupport::TestCase
  context("A ban") do
    context("created by an admin") do
      setup do
        @banner = create(:admin_user)
      end

      should("set the is_banned flag on the user") do
        user = create(:user)
        ban = build(:ban, user: user, creator: @banner)
        ban.save
        user.reload

        assert_predicate(user, :is_banned?)
      end

      should("not be valid against another admin") do
        user = create(:admin_user)
        ban = build(:ban, user: user, creator: @banner)
        ban.save

        assert_predicate(ban.errors, :any?)
      end

      should("be valid against anyone who is not an admin") do
        user = create(:moderator_user)
        ban = create(:ban, user: user, creator: @banner)

        assert_empty(ban.errors)

        user = create(:trusted_user)
        ban = create(:ban, user: user, creator: @banner)

        assert_empty(ban.errors)

        user = create(:user)
        ban = create(:ban, user: user, creator: @banner)

        assert_empty(ban.errors)
      end
    end

    context("created by a moderator") do
      setup do
        @banner = create(:moderator_user)
      end

      should("not be valid against an admin or moderator") do
        user = create(:admin_user)
        ban = build(:ban, user: user, creator: @banner)
        ban.save

        assert_predicate(ban.errors, :any?)

        user = create(:moderator_user)
        ban = build(:ban, user: user, creator: @banner)
        ban.save

        assert_predicate(ban.errors, :any?)
      end

      should("be valid against anyone who is not an admin or a moderator") do
        user = create(:trusted_user)
        ban = create(:ban, user: user, creator: @banner)

        assert_empty(ban.errors)

        user = create(:user)
        ban = create(:ban, user: user, creator: @banner)

        assert_empty(ban.errors)
      end
    end

    should("initialize the expiration date") do
      user = create(:user)
      admin = create(:admin_user)
      ban = create(:ban, user: user, creator: admin)

      assert_not_nil(ban.expires_at)
    end

    should("update the user's feedback") do
      user = create(:user)
      admin = create(:admin_user)

      assert_empty(user.feedback)
      create(:ban, user: user, creator: admin)

      assert_not(user.feedback.empty?)
      assert_equal("negative", user.feedback.last.category)
    end

    should("require a duration on create") do
      ban = build(:ban, duration: nil)

      assert_not(ban.valid?)
      assert_includes(ban.errors[:duration], "can't be blank")
    end

    should("not change expires_at when updated with a blank duration") do
      admin = create(:admin_user)
      ban = create(:ban, creator: admin, duration: 60)
      expires_at = ban.expires_at

      ban.update(duration: nil, reason: "updated reason")

      assert_equal("updated reason", ban.reason)
      assert_equal(expires_at.to_i, ban.reload.expires_at.to_i)
    end

    should("still change expires_at when updated with a real duration") do
      admin = create(:admin_user)
      ban = create(:ban, creator: admin, duration: 60)

      ban.update(duration: 30)

      assert_in_delta(30.days.from_now, ban.expires_at, 1.minute)
    end
  end

  context("Searching for a ban") do
    should("find a given ban") do
      user = create(:user)
      ban = create(:ban, user: user)
      params = {
        user_name:    user.name,
        creator_name: ban.creator.name,
        reason:       ban.reason,
        expired:      false,
        order:        :id_desc,
      }

      bans = Ban.search(params, create(:admin_user))

      assert_equal(1, bans.length)
      assert_equal(ban.id, bans.first.id)
    end

    context("by user id") do
      setup do
        @admin = create(:admin_user)
        @user = create(:user)
      end

      context("when only expired bans exist") do
        setup do
          @ban = create(:ban, user: @user, creator: @admin, duration: 1)
        end

        should("not return expired bans") do
          travel_to(2.days.from_now) do
            assert_not(Ban.is_banned?(@user))
          end
        end
      end

      context("when active bans still exist") do
        setup do
          @ban = create(:ban, user: @user, creator: @admin, duration: 1)
        end

        should("return active bans") do
          assert(Ban.is_banned?(@user))
        end
      end
    end
  end
end
