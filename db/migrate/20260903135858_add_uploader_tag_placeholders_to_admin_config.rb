# frozen_string_literal: true

class AddUploaderTagPlaceholdersToAdminConfig < ExtendedMigration[8.1]
  def change
    add_column(:admin_config, :artist_tag_placeholder, :string, null: false, default: "artist_name, unknown_artist, anonymous_artist etc.")
    add_column(:admin_config, :character_tag_placeholder, :string, null: false, default: "character_name solo_focus 1_male 2_females etc.")
    add_column(:admin_config, :species_tag_placeholder, :string, null: false, default: "bear dragon hyena rat newt etc.")
    add_column(:admin_config, :content_tag_placeholder, :string, null: false, default: "cub scatplay watersports diaper my_little_pony vore rape hyper etc.")
    AdminConfig.delete_cache
  end
end
