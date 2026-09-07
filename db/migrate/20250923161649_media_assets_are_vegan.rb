# frozen_string_literal: true

class MediaAssetsAreVegan < ActiveRecord::Migration[7.1]
  def change
    rename_column(:media_metadata, :meatadata, :metadata)
  end
end
