# frozen_string_literal: true

class ColumnTypeConsistency < ActiveRecord::Migration[7.1]
  def change
    bulk_change_column_types({
      api_keys:                   %i[id user_id],
      artist_urls:                %i[id artist_id],
      artist_versions:            %i[id artist_id updater_id],
      artists:                    %i[id creator_id linked_user_id],
      bans:                       %i[id user_id banner_id],
      bulk_update_requests:       %i[id creator_id forum_topic_id approver_id forum_post_id],
      comment_votes:              %i[id comment_id user_id],
      comments:                   %i[id post_id creator_id updater_id warning_user_id],
      destroyed_posts:            %i[post_id destroyer_id uploader_id],
      dmail_filters:              %i[id user_id],
      dmails:                     %i[id owner_id from_id to_id],
      edit_histories:             %i[versionable_id user_id],
      email_blacklists:           %i[creator_id],
      exception_logs:             %i[user_id],
      favorites:                  %i[user_id post_id],
      forum_post_votes:           %i[forum_post_id user_id],
      forum_posts:                %i[id topic_id creator_id updater_id warning_user_id],
      forum_topics:               %i[id creator_id updater_id category_id],
      ip_bans:                    %i[id creator_id],
      mod_actions:                %i[id creator_id subject_id],
      news_updates:               %i[id creator_id updater_id],
      note_versions:              %i[id note_id post_id updater_id],
      notes:                      %i[id creator_id post_id],
      pool_versions:              %i[pool_id updater_id],
      pools:                      %i[id creator_id],
      post_approvals:             %i[id user_id post_id],
      post_disapprovals:          %i[user_id post_id],
      post_flags:                 %i[id post_id creator_id],
      post_replacements:          %i[post_id creator_id approver_id uploader_id_on_approve],
      post_set_maintainers:       %i[post_set_id user_id],
      post_sets:                  %i[creator_id],
      post_versions:              %i[post_id updater_id parent_id],
      post_votes:                 %i[id post_id user_id],
      posts:                      %i[id uploader_id approver_id parent_id],
      staff_notes:                %i[creator_id],
      tag_aliases:                %i[id creator_id approver_id forum_post_id forum_topic_id],
      tag_implications:           %i[id creator_id approver_id forum_post_id forum_topic_id],
      tag_versions:               %i[tag_id updater_id],
      tags:                       %i[id],
      takedowns:                  %i[creator_id approver_id],
      tickets:                    %i[creator_id handler_id claimant_id accused_id model_id],
      uploads:                    %i[id uploader_id post_id parent_id],
      user_feedbacks:             %i[id user_id creator_id updater_id],
      user_name_change_requests:  %i[id user_id approver_id],
      user_password_reset_nonces: %i[id user_id],
      users:                      %i[id avatar_id],
      wiki_page_versions:         %i[id wiki_page_id updater_id],
      wiki_pages:                 %i[id creator_id updater_id],
    }, from: :integer, to: :bigint)

    bulk_change_column_types({
      comments:      %i[notified_mentions],
      forum_posts:   %i[notified_mentions],
      pool_versions: %i[post_ids added_post_ids removed_post_ids],
      pools:         %i[post_ids],
      post_sets:     %i[post_ids],
    }, from: :integer, to: :bigint, array: true) do |table, column|
      change_column_default(table, column, from: -> { "'{}'::integer[]" }, to: -> { "'{}'::bigint[]" })
    end
  end
end
