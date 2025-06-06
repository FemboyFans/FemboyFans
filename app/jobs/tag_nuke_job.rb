# frozen_string_literal: true

class TagNukeJob < ApplicationJob
  queue_as(:tags)
  sidekiq_options(lock: :until_executed, lock_args_method: :lock_args)

  def self.lock_args(args)
    [args[0]]
  end

  def perform(*args)
    tag_name = args[0]
    tag = Tag.find_by_normalized_name(tag_name)
    updater_id = args[1]
    updater_ip_addr = args[2]
    return if tag.nil?

    updater = User.find(updater_id)

    CurrentUser.scoped(updater, updater_ip_addr) do
      create_undo_information(tag)
      CurrentUser.as_system { migrate_posts(tag.name) }
      ModAction.log!(:nuke_tag, Tag.find_by(name: tag_name), tag_name: tag_name)
    end
  end

  def migrate_posts(tag_name)
    Post.sql_raw_tag_match(tag_name).find_each do |post|
      post.with_lock do
        post.automated_edit = true
        post.remove_tag(tag_name)
        post.save
      end
    end
  end

  def create_undo_information(tag)
    Post.transaction do
      Post.without_timeout do
        post_ids = []
        Post.sql_raw_tag_match(tag.name).find_each do |post|
          post_ids << post.id
        end
        TagRelUndo.create!(tag_rel: tag, undo_data: post_ids)
      end
    end
  end

  def self.process_undo!(tag)
    CurrentUser.as_system do
      TagRelUndo.where(tag_rel: tag, applied: false).find_each do |tag_rel_undo|
        Post.where(id: tag_rel_undo.undo_data).find_each do |post|
          post.automated_edit = true
          post.add_tag(tag.name)
          post.save
        end
        tag_rel_undo.update(applied: true)
      end
    end
  end
end
