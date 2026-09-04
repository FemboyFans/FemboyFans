# frozen_string_literal: true

class AddIsDeletedToBans < ExtendedMigration[8.1]
  def change
    add_column(:bans, :is_deleted, :boolean, null: false, default: false)
  end
end
