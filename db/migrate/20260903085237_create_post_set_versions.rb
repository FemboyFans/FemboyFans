# frozen_string_literal: true

class CreatePostSetVersions < ActiveRecord::Migration[8.1]
  def change
    create_table(:post_set_versions) do |t|
      t.references(:post_set, foreign_key: true)
      t.references(:updater, foreign_key: { to_table: :users })
      t.inet(:updater_ip_addr, null: false)
      t.integer(:post_ids, array: true, null: false, default: [])
      t.integer(:added_post_ids, array: true, null: false, default: [])
      t.integer(:removed_post_ids, array: true, null: false, default: [])
      t.string(:name, null: false)
      t.boolean(:name_changed, null: false) # rubocop:disable Rails/ThreeStateBooleanColumn
      t.string(:shortname, null: false)
      t.boolean(:shortname_changed, null: false) # rubocop:disable Rails/ThreeStateBooleanColumn
      t.text(:description, null: false)
      t.boolean(:description_changed, null: false) # rubocop:disable Rails/ThreeStateBooleanColumn
      t.boolean(:is_public, null: false) # rubocop:disable Rails/ThreeStateBooleanColumn
      t.boolean(:is_public_changed, null: false) # rubocop:disable Rails/ThreeStateBooleanColumn
      t.boolean(:transfer_on_delete, null: false) # rubocop:disable Rails/ThreeStateBooleanColumn
      t.boolean(:transfer_on_delete_changed, null: false) # rubocop:disable Rails/ThreeStateBooleanColumn
      t.integer(:maintainer_ids, array: true, null: false, default: [])
      t.integer(:added_maintainer_ids, array: true, null: false, default: [])
      t.integer(:removed_maintainer_ids, array: true, null: false, default: [])
      t.integer(:version, null: false)
      t.timestamps
    end

    add_column(:users, :set_update_count, :integer, null: false, default: 0)
  end
end
