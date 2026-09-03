# frozen_string_literal: true

module PostSetVersionsHelper
  def post_set_version_posts_diff(post_set_version)
    changes = []

    post_set_version.added_post_ids.each do |post_id|
      changes << tag.ins(link_to(post_id, post_path(post_id)))
    end

    post_set_version.removed_post_ids.each do |post_id|
      changes << tag.del(link_to(post_id, post_path(post_id)))
    end

    safe_join(changes, " ")
  end

  def post_set_version_maintainers_diff(post_set_version)
    ids = post_set_version.added_maintainer_ids + post_set_version.removed_maintainer_ids
    users = User.where(id: ids).index_by(&:id)
    changes = []

    post_set_version.added_maintainer_ids.each do |user_id|
      next unless users[user_id]
      changes << tag.ins(link_to_user(users[user_id]))
    end

    post_set_version.removed_maintainer_ids.each do |user_id|
      next unless users[user_id]
      changes << tag.del(link_to_user(users[user_id]))
    end

    safe_join(changes, " ")
  end
end
