# frozen_string_literal: true

class SplitPoolStringIntoSeparateArrays < ActiveRecord::Migration[8.1]
  def change
    add_column(:posts, :pool_ids, :bigint, array: true, null: false, default: [])
    add_column(:posts, :public_set_ids, :bigint, array: true, null: false, default: [])
    add_column(:posts, :private_set_ids, :bigint, array: true, null: false, default: [])
    add_index(:posts, :pool_ids, using: :gin)
    add_index(:posts, :public_set_ids, using: :gin)
    add_index(:posts, :private_set_ids, using: :gin)
    remove_column(:posts, :pool_string, :text, null: false, default: "")

    update_change_seq(add: %i[pool_ids public_set_ids])
  end
end
