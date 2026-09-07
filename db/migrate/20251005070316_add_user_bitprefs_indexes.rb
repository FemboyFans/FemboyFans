# frozen_string_literal: true

class AddUserBitprefsIndexes < ActiveRecord::Migration[7.1]
  def change
    %i[can_approve_posts enable_privacy_mode unrestricted_uploads can_manage_aibur].each do |pref|
      bit = User::Preferences.const_get(pref.upcase)
      add_index(:users, :id, name: :"index_users_on_bit_prefs_#{pref}_true", where: "(bit_prefs & #{bit}) = #{bit}")
      add_index(:users, :id, name: :"index_users_on_bit_prefs_#{pref}_false", where: "(bit_prefs & #{bit}) = 0")
    end
  end
end
