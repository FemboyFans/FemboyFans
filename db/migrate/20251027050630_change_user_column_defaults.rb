# frozen_string_literal: true

class ChangeUserColumnDefaults < ActiveRecord::Migration[7.1]
  def change
    change_column_default(:users, :blacklisted_tags, from: "spoilers\nguro\nscat\nfurry -rating:s", to: "")
    change_column_default(:users, :time_zone, from: "Eastern Time (US & Canada)", to: "Central Time (US & Canada)")
  end
end
