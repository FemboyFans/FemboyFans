# frozen_string_literal: true

class AddImportantTagCategory < ActiveRecord::Migration[7.1]
  def change
    add_column(:posts, :tag_count_important, :integer, default: 0, null: false)
    reversible do |r|
      r.up do
        execute(<<~SQL,
          CREATE OR REPLACE FUNCTION public.posts_trigger_change_seq() RETURNS trigger
              LANGUAGE plpgsql
          AS $$
          DECLARE
              old_md5 text;
              new_md5 text;
          BEGIN
              SELECT md5 INTO old_md5 FROM upload_media_assets WHERE id = OLD.upload_media_asset_id;
              SELECT md5 INTO new_md5 FROM upload_media_assets WHERE id = NEW.upload_media_asset_id;

              IF NEW.source IS DISTINCT FROM OLD.source
                  OR NEW.rating IS DISTINCT FROM OLD.rating
                  OR NEW.is_note_locked IS DISTINCT FROM OLD.is_note_locked
                  OR NEW.is_rating_locked IS DISTINCT FROM OLD.is_rating_locked
                  OR NEW.is_status_locked IS DISTINCT FROM OLD.is_status_locked
                  OR NEW.is_pending IS DISTINCT FROM OLD.is_pending
                  OR NEW.is_flagged IS DISTINCT FROM OLD.is_flagged
                  OR NEW.is_deleted IS DISTINCT FROM OLD.is_deleted
                  OR NEW.approver_id IS DISTINCT FROM OLD.approver_id
                  OR NEW.last_noted_at IS DISTINCT FROM OLD.last_noted_at
                  OR NEW.tag_string IS DISTINCT FROM OLD.tag_string
                  OR NEW.parent_id IS DISTINCT FROM OLD.parent_id
                  OR NEW.has_active_children IS DISTINCT FROM OLD.has_active_children
                  OR NEW.bit_flags IS DISTINCT FROM OLD.bit_flags
                  OR NEW.locked_tags IS DISTINCT FROM OLD.locked_tags
                  OR NEW.description IS DISTINCT FROM OLD.description
                  OR NEW.bg_color IS DISTINCT FROM OLD.bg_color
                  OR NEW.is_comment_disabled IS DISTINCT FROM OLD.is_comment_disabled
                  OR NEW.is_comment_locked IS DISTINCT FROM OLD.is_comment_locked
                  OR NEW.thumbnail_frame IS DISTINCT FROM OLD.thumbnail_frame
                  OR NEW.min_edit_level IS DISTINCT FROM OLD.min_edit_level
                  OR NEW.last_commented_at IS DISTINCT FROM OLD.last_commented_at
                  OR NEW.comment_count IS DISTINCT FROM OLD.comment_count
                  OR NEW.qtags IS DISTINCT FROM OLD.qtags
                  OR NEW.tag_count_general IS DISTINCT FROM OLD.tag_count_general
                  OR NEW.tag_count_artist IS DISTINCT FROM OLD.tag_count_artist
                  OR NEW.tag_count_character IS DISTINCT FROM OLD.tag_count_character
                  OR NEW.tag_count_copyright IS DISTINCT FROM OLD.tag_count_copyright
                  OR NEW.tag_count_meta IS DISTINCT FROM OLD.tag_count_meta
                  OR NEW.tag_count_species IS DISTINCT FROM OLD.tag_count_species
                  OR NEW.tag_count_invalid IS DISTINCT FROM OLD.tag_count_invalid
                  OR NEW.tag_count_lore IS DISTINCT FROM OLD.tag_count_lore
                  OR NEW.tag_count_gender IS DISTINCT FROM OLD.tag_count_gender
                  OR NEW.tag_count_contributor IS DISTINCT FROM OLD.tag_count_contributor
                  OR NEW.tag_count_important IS DISTINCT FROM OLD.tag_count_important
                  OR old_md5 IS DISTINCT FROM new_md5
              THEN
                  NEW.change_seq = nextval('public.posts_change_seq_seq');
              END IF;
              RETURN NEW;
          END;
          $$;
        SQL
               )
      end
    end
  end
end
