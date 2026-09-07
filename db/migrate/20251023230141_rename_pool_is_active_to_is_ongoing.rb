# frozen_string_literal: true

class RenamePoolIsActiveToIsOngoing < ActiveRecord::Migration[7.1]
  def change
    rename_column(:pools, :is_active, :is_ongoing)
    rename_column(:pool_versions, :is_active, :is_ongoing)
    add_column(:pool_versions, :is_ongoing_changed, :boolean, default: false, null: false)
  end
end
