# frozen_string_literal: true

class AddIsInProgressToPosts < ActiveRecord::Migration[7.1]
  def change
    add_column(:posts, :is_in_progress, :boolean, null: false, default: false)
    update_change_seq(add: :is_in_progress)
  end
end
