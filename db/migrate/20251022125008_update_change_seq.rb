# frozen_string_literal: true

class UpdateChangeSeq < ActiveRecord::Migration[7.1]
  def up
    update_change_seq(%w[
      source rating is_note_locked is_rating_locked is_status_locked is_pending is_flagged is_deleted is_appealed approver_id last_noted_at tag_string typed_tag_string parent_id
      has_children has_active_children bit_flags locked_tags description bg_color is_comment_disabled is_comment_locked thumbnail_frame min_edit_level last_commented_at comment_count
      qtags tag_count_general tag_count_artist tag_count_contributor tag_count_character tag_count_copyright tag_count_meta tag_count_species tag_count_invalid tag_count_lore
      tag_count_gender tag_count_important
    ])
  end
end
