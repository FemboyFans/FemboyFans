# frozen_string_literal: true

class AddIsAppealedToPosts < ActiveRecord::Migration[7.1]
  def change
    add_column(:posts, :is_appealed, :boolean, null: false, default: false)
  end
end
