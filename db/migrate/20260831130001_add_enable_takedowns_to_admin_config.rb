# frozen_string_literal: true

class AddEnableTakedownsToAdminConfig < ExtendedMigration[8.1]
  def change
    add_column(:admin_config, :enable_takedowns, :boolean, null: false, default: false)
    AdminConfig.delete_cache
  end
end
