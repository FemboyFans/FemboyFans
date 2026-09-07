# frozen_string_literal: true

class RemoveExtraneousBurVersionsIntegerColumn < ActiveRecord::Migration[7.1]
  def change
    remove_column(:bulk_update_request_versions, :integer, :integer, default: 1, null: false)
  end
end
