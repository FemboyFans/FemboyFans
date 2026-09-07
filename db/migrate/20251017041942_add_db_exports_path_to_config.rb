# frozen_string_literal: true

class AddDbExportsPathToConfig < ActiveRecord::Migration[7.1]
  with_config_override!

  def change
    add_column(:config, :db_exports_path, :string, default: "/db_exports")
    Config.delete_cache
  end
end
