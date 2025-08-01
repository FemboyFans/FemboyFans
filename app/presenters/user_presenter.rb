# frozen_string_literal: true

class UserPresenter
  attr_reader(:user)

  def initialize(user)
    @user = user
  end

  def name
    user.pretty_name
  end

  def level
    user.level_string_pretty
  end

  def ban_reason(template)
    if user.is_banned?
      reason = template.format_text(user.recent_ban.reason)
      edit = template.link_to_enclosed("edit", template.edit_ban_path(user.recent_ban), if: template.policy(user.recent_ban).edit?)
      %(#{reason}\n\n Expires #{user.recent_ban.expire_days_tagged} #{template.link_to_enclosed("#{user.bans.count} #{'ban'.pluralize(user.bans.count)} total", template.bans_path(search: { user_id: user.id }))} #{edit}).html_safe
    end
  end

  def permissions
    permissions = []

    if user.can_approve_posts?
      permissions << "approve posts"
    end

    if user.unrestricted_uploads?
      permissions << "unrestricted uploads"
    end

    if user.can_manage_aibur?
      permissions << "manage tag change requests"
    end

    if CurrentUser.user.is_moderator?
      if user.no_flagging?
        permissions << "no flagging"
      end

      if user.no_replacements?
        permissions << "no replacements"
      end

      if user.no_aibur_voting?
        permissions << "no tag change request voting"
      end
    end

    permissions.join(", ")
  end

  def permissions_compact
    perms = permissions.split(", ")
    return permissions if perms.length <= 2
    visible = perms.slice(0, 2)
    %(<text class="permissions-list" data-short="#{visible.join(', ')}" data-full="#{perms.join(', ')}">#{visible.join(', ')}</text> <a href="#" title="Expand" class="expand-permissions-link">»</a><a title="Collapse" href="#" style="display: none;" class="collapse-permissions-link">«</a>).html_safe
  end

  def upload_limit(_template)
    if user.unrestricted_uploads?
      return "none"
    end

    upload_limit_pieces = user.upload_limit_pieces

    %{<abbr title="Base Upload Limit">#{user.base_upload_limit}</abbr>
    + (<abbr title="Approved Posts">#{upload_limit_pieces[:approved]}</abbr> / 10)
    - (<abbr title="Deleted or Replaced Posts, Rejected Replacements\n#{upload_limit_pieces[:deleted_ignore]} of your Replaced Posts do not affect your upload limit">#{upload_limit_pieces[:deleted]}</abbr> / 4)
    - <abbr title="Pending or Flagged Posts, Pending Replacements">#{upload_limit_pieces[:pending]}</abbr>
    = <abbr title="User Upload Limit Remaining">#{user.upload_limit}</abbr>}.html_safe
  end

  def artwork(name)
    Post.tag_match(name, CurrentUser.user).limit(10)
  end

  def uploads
    Post.tag_match("user:#{user.name}", CurrentUser.user).limit(8)
  end

  def has_active_uploads?
    (user.post_upload_count - user.post_deleted_count) > 0
  end

  def show_uploads?
    has_active_uploads? || CurrentUser.user.is_moderator?
  end

  def favorites
    ids = Favorite.where(user_id: user.id).order(created_at: :desc).limit(50).pluck(:post_id)[0..7]
    Post.where(id: ids).sort_by { |post| ids.index(post.id) }
  end

  def has_favorites?
    user.favorite_count > 0
  end

  def upload_count(template)
    template.link_to(user.post_upload_count, template.posts_path(tags: "user:#{user.name}"))
  end

  def active_upload_count(template)
    template.link_to(user.post_active_count, template.posts_path(tags: "user:#{user.name}"))
  end

  def deleted_upload_count(template)
    template.link_to(user.post_deleted_count, template.deleted_posts_path(user_id: user.id))
  end

  def replaced_upload_count(template)
    template.link_to(user.own_post_replaced_count, template.post_replacements_path(search: { uploader_id_on_approve: user.id }))
  end

  def rejected_replacements_count(template)
    template.link_to(user.post_replacement_rejected_count, template.post_replacements_path(search: { creator_id: user.id, status: "rejected" }))
  end

  def favorite_count(template)
    template.link_to(user.favorite_count, template.favorites_path(user_id: user.id))
  end

  def comment_count(template)
    template.link_to(user.comment_count, template.comments_path(search: { creator_id: user.id }, group_by: "comment"))
  end

  def commented_posts_count(template)
    template.link_to(commented_on_posts_count, template.posts_path(tags: "commenter:#{user.name} order:comment_bumped"))
  end

  def commented_on_posts_count
    Post.system_count("commenter:#{user.name}", enable_safe_mode: false)
  end

  def post_version_count(template)
    template.link_to(user.post_update_count, template.post_versions_path(lr: user.id, search: { updater_id: user.id }))
  end

  def note_version_count(template)
    template.link_to(user.note_version_count, template.note_versions_path(search: { updater_id: user.id }))
  end

  def noted_posts_count(template)
    count = Post.system_count("noteupdater:#{user.name}", enable_safe_mode: false)
    template.link_to(count, template.posts_path(tags: "noteupdater:#{user.name} order:note"))
  end

  def wiki_page_version_count(template)
    template.link_to(user.wiki_page_version_count, template.wiki_page_versions_path(search: { updater_id: user.id }))
  end

  def artist_version_count(template)
    template.link_to(user.artist_version_count, template.artist_versions_path(search: { updater_id: user.id }))
  end

  def forum_post_count(template)
    template.link_to(user.forum_post_count, template.forum_posts_path(search: { creator_id: user.id }))
  end

  def pool_version_count(template)
    template.link_to(user.pool_version_count, template.pool_versions_path(search: { updater_id: user.id }))
  end

  def flag_count(template)
    template.link_to(user.flag_count, template.post_flags_path(search: { creator_id: user.id }))
  end

  def ticket_count(template)
    template.link_to(user.ticket_count, template.tickets_path(search: { creator_id: user.id }))
  end

  def approval_count(template)
    template.link_to(Post.where("approver_id = ?", user.id).count, template.posts_path(tags: "approver:#{user.name}"))
  end

  def feedbacks
    positive = user.positive_feedback_count
    neutral = user.neutral_feedback_count
    negative = user.negative_feedback_count
    deleted = CurrentUser.user.is_staff? ? user.deleted_feedback_count : 0

    return "0" if (positive + neutral + negative + deleted) == 0

    total_class = (positive - negative) > 0 ? "user-feedback-positive" : "user-feedback-negative"
    total_class = "" if (positive - negative) == 0
    positive_html = %(<span class="user-feedback-positive">#{positive}</span>).html_safe if positive > 0
    neutral_html = %(<span class="user-feedback-neutral">#{neutral}</span>).html_safe if neutral > 0
    negative_html = %(<span class="user-feedback-negative">#{negative}</span>).html_safe if negative > 0
    deleted_html = %(<span class="user-feedback-deleted">#{deleted}</span>).html_safe if deleted > 0
    list_html = "#{positive_html} #{neutral_html} #{negative_html} #{deleted_html}".strip

    %{<span class="#{total_class}">#{positive - negative}</span> (#{list_html})}.html_safe
  end

  def previous_names(template)
    user.user_name_change_requests.map { |req| template.link_to(req.original_name, req) }.join(" -> ").html_safe
  end

  def favorite_tags_with_types
    tag_names = user&.favorite_tags.to_s.split
    tag_names = TagAlias.to_aliased(tag_names)
    indices = tag_names.each_with_index.to_h { |x, i| [x, i] }
    tags = Tag.where(name: tag_names).map do |tag|
      {
        name:        tag.name,
        count:       tag.post_count,
        category_id: tag.category,
      }
    end
    tags.sort_by { |entry| indices[entry[:name]] }
  end

  def recent_tags_with_types
    versions = PostVersion.where(updater_id: user.id).where("updated_at > ?", 1.hour.ago).order(id: :desc).limit(150)
    tags = versions.flat_map(&:added_tags)
    tags = tags.group_by(&:itself).transform_values(&:size).sort_by { |tag, count| [-count, tag] }.map(&:first)
    tags = tags.take(50)
    Tag.where(name: tags).map do |tag|
      {
        name:        tag.name,
        count:       tag.post_count,
        category_id: tag.category,
      }
    end
  end

  def policy
    UserPresenterPolicy.new(CurrentUser.user, self)
  end
end
