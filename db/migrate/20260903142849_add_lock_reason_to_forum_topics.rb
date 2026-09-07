# frozen_string_literal: true

class AddLockReasonToForumTopics < ActiveRecord::Migration[8.1]
  def change
    add_column(:forum_topics, :lock_reason, :text)
  end
end
