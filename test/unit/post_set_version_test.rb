# frozen_string_literal: true

require("test_helper")

class PostSetVersionTest < ActiveSupport::TestCase
  context("A post set version") do
    setup do
      @user = create(:user, created_at: 1.month.ago)
      @set = create(:post_set, creator: @user)
    end

    should("record the initial state as version 1") do
      version = @set.versions.first

      assert_equal(1, version.version)
      assert_equal(%w[created], version.changes_text)
    end

    should("increment the version number per post set") do
      other_set = create(:post_set, creator: @user)
      @set.update_with!(@user, name: "renamed_set")

      assert_equal(2, @set.versions.last.version)
      assert_equal(1, other_set.versions.last.version)
    end

    context("diffing against the previous version") do
      setup do
        @p1 = create(:post)
        @p2 = create(:post)
        @set.add!(@p1, @user)
        @set.add!(@p2, @user)
      end

      should("track added and removed posts") do
        @set.remove!(@p1, @user)
        version = @set.versions.last

        assert_equal([], version.added_post_ids)
        assert_equal([@p1.id], version.removed_post_ids)
        assert_includes(version.changes_text, "posts (-1)")
      end

      should("track added and removed maintainers") do
        @set.update_with!(@user, is_public: true)
        maintainer = create(:user)
        record = PostSetMaintainer.create!(post_set: @set, user: maintainer, status: "pending")
        record.approve!
        PostSetVersion.queue(@set.reload, maintainer.resolvable("1.2.3.4"))

        version = @set.versions.last

        assert_equal([maintainer.id], version.added_maintainer_ids)
        assert_equal([], version.removed_maintainer_ids)
        assert_includes(version.changes_text, "maintainers (+1)")
      end

      should("flag which scalar fields changed") do
        @set.update_with!(@user, name: "renamed_set", shortname: "renamed_shortname", description: "new desc")
        version = @set.versions.last

        assert_predicate(version, :name_changed?)
        assert_predicate(version, :shortname_changed?)
        assert_predicate(version, :description_changed?)
        assert_not(version.is_public_changed?)
        assert_equal(%w[name shortname description], version.changes_text)
      end

      should("describe visibility changes") do
        @set.update_with!(@user, is_public: true)

        assert_includes(@set.versions.last.changes_text, "made public")
      end

      should("describe transfer on delete changes") do
        @set.update_with!(@user, transfer_on_delete: true)

        assert_includes(@set.versions.last.changes_text, "transfer on delete enabled")
      end
    end

    context("undoing a version") do
      setup do
        @set.update_with!(@user, name: "renamed_set")
      end

      should("restore the previous state") do
        original_name = @set.versions.first.name
        @set.versions.last.undo!(@user)

        assert_equal(original_name, @set.reload.name)
      end

      should("not allow undoing version 1") do
        assert_raises(Undoable::UndoError) { @set.versions.first.undo }
      end
    end

    context(".queue") do
      should("snapshot the set's current attributes") do
        @set.update_column(:transfer_on_delete, true)
        version = PostSetVersion.queue(@set.reload, @user.resolvable("1.2.3.4"))

        assert_equal(@set.name, version.name)
        assert_equal(@set.shortname, version.shortname)
        assert_equal(@set.description, version.description)
        assert_equal(@set.is_public, version.is_public)
        assert(version.transfer_on_delete)
        assert_equal(@user.id, version.updater_id)
        assert_equal("1.2.3.4", version.updater_ip_addr.to_s)
      end
    end
  end
end
