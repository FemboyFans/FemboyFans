# frozen_string_literal: true

class AddBuiltinWikiPageNamesToAdminConfig < ExtendedMigration[8.1]
  def change
    add_column(:admin_config, :privacy_policy_wiki_page, :string, null: false, default: "help:privacy_policy")
    add_column(:admin_config, :terms_of_service_wiki_page, :string, null: false, default: "help:terms_of_service")
    add_column(:admin_config, :contact_wiki_page, :string, null: false, default: "help:contact")
    add_column(:admin_config, :takedown_wiki_page, :string, null: false, default: "help:takedown")
    add_column(:admin_config, :takedown_verification_wiki_page, :string, null: false, default: "help:takedown_verification")
    add_column(:admin_config, :staff_wiki_page, :string, null: false, default: "help:staff")
    add_column(:admin_config, :home_wiki_page, :string, null: false, default: "help:home")
    add_column(:admin_config, :tag_genders_howto_wiki_page, :string, null: false, default: "howto:tag_genders")
    add_column(:admin_config, :tag_what_you_see_wiki_page, :string, null: false, default: "tag_what_you_see")
    AdminConfig.delete_cache
  end
end
