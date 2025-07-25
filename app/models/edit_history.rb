# frozen_string_literal: true

class EditHistory < ApplicationRecord
  belongs_to(:versionable, polymorphic: true)
  belongs_to_user(:updater, ip: true)

  VERSIONABLE_TYPES = %w[ForumPost Comment].freeze

  validates(:versionable_type, inclusion: { in: VERSIONABLE_TYPES })

  VALUES = %i[old_topic_id old_topic_title new_topic_id new_topic_title].freeze
  store_accessor(:extra_data, *VALUES)

  scope(:edit_type, ->(type) { where(edit_type: type) })
  scope(:hidden, -> { edit_type("hide") })
  scope(:marked, -> { edit_type(%w[mark_warning mark_record mark_ban]) })
  scope(:edited, -> { edit_type("edit") })
  scope(:merged, -> { edit_type("merge") })
  scope(:unmerged, -> { edit_type("unmerge") })

  EDIT_MAP = {
    hide:            "Hidden",
    unhide:          "Unhidden",
    stick:           "Stickied",
    unstick:         "Unstickied",
    mark_warning:    "Marked For Warning",
    wark_record:     "Marked For Record",
    mark_ban:        "Marked For Ban",
    unmark:          "Unmarked",
    merge:           "Merged",
    unmerge:         "Unmerged",
    voting_enabled:  "Voting Enabled",
    voting_disabled: "Voting Disabled",
  }.freeze

  KNOWN_TYPES = %i[
    comment
    forum_post
  ].freeze

  KNOWN_EDIT_TYPES = EDIT_MAP.keys

  CONTENTFUL_TYPES = %w[original edit].freeze

  def pretty_edit_type
    edit_type.titleize
  end

  def previous_version(versions)
    return nil if version == 1 || (index = versions.index(self)) < 1
    versions[index - 1]
  end

  def previous_contentful_edit(versions)
    return nil if version == 1
    previous = previous_version(versions)
    return previous if previous.present? && previous.is_contentful?
    # we might be on a page that doesn't contain the most recent contentful edit, query to try to find it
    EditHistory.where(versionable_id: versionable_id, versionable_type: versionable_type, edit_type: CONTENTFUL_TYPES).and(EditHistory.where(EditHistory.arel_table[:version].lt(version))).last
  end

  def text_content
    case edit_type
    when *CONTENTFUL_TYPES
      return subject if subject.present?
      body
    when "merge"
      %(<b>Merged into <a href="/forums/topics/#{new_topic_id}">#{new_topic_title}</a> from <a href="/forums/topics/#{old_topic_id}">#{old_topic_title}</a>.</b>).html_safe
    when "unmerge"
      %(<b> Unmerged <a href="/forums/topics/#{new_topic_id}">#{new_topic_title}</a> from <a href="/forums/topics/#{old_topic_id}">#{old_topic_title}</a>.</b>).html_safe
    else
      "<b>#{EDIT_MAP[edit_type.to_sym] || pretty_edit_type}</b>".html_safe
    end
  end

  def is_contentful?
    CONTENTFUL_TYPES.include?(edit_type)
  end

  def html_name
    case versionable_type
    when "ForumPost"
      "Forum Post ##{versionable_id}"
    when "Comment"
      "Comment ##{versionable_id}"
    else
      "#{versionable_type} ##{versionable_id}"
    end
  end

  def link(template)
    case versionable_type
    when "ForumPost"
      template.forum_post_path(versionable_id)
    when "Comment"
      template.comment_path(versionable_id)
    else
      template.edit_histories_path(versionable_type: versionable_type, versionable_id: versionable_id)
    end
  end

  def html_link(template)
    template.link_to(html_name, link(template))
  end

  def html_title(template)
    template.tag.h1 do
      template.tag.span("Edits for ") + html_link(template)
    end
  end

  def page(limit = 20)
    limit = limit.to_i
    return 1 if limit <= 0
    (version / limit).ceil + 1
  end

  def previous
    EditHistory.where(versionable_id: versionable_id, versionable_type: versionable_type).where(version: ...version).order(version: :desc).first
  end

  module SearchMethods
    def original
      edit_type("original").and(where(version: 1)).first
    end

    def search(params, user)
      q = super

      if params[:versionable_type].present?
        q = q.where(versionable_type: params[:versionable_type])
      end

      if params[:versionable_id].present?
        q = q.where(versionable_id: params[:versionable_id])
      end

      if params[:edit_type].present?
        q = q.where(edit_type: params[:edit_type])
      else
        q = q.where.not(edit_type: "original")
      end

      q = q.where_user(:user_id, :user, params)

      if params[:ip_addr].present?
        q = q.where("ip_addr <<= ?", params[:ip_addr])
      end

      q.apply_basic_order(params)
    end
  end

  extend(SearchMethods)

  def self.available_includes
    %i[user versionable]
  end

  def visible?(user)
    user.is_moderator?
  end

  def json_keys
    VALUES
  end
end
