# frozen_string_literal: true

class PostPresenter < Presenter
  attr_reader(:pool)

  delegate(:post_show_sidebar_tag_list_html, :split_tag_list_text, :inline_tag_list_html, to: :tag_set_presenter)

  def self.preview(post, options = {})
    if post.nil?
      return ""
    end

    if !options[:show_deleted] && post.is_deleted? && options[:tags] !~ /(?:status:(?:all|any|deleted|modqueue|appealed))|(?:deletedby:)|(?:delreason:)/i
      return ""
    end

    if post.loginblocked?(CurrentUser.user) || post.safeblocked?(CurrentUser.user)
      return ""
    end

    options[:stats] ||= !options[:avatar] && !options[:inline]

    locals = {
      post:  post,
      views: options[:views],
    }

    locals[:article_attrs] = {
      "id"    => "post_#{post.id}",
      "class" => preview_class(post, **options).join(" "),
    }.merge(data_attributes(post))

    locals[:link_target] = options[:link_target] || post

    locals[:link_params] = {}
    if options[:tags].present?
      locals[:link_params]["q"] = options[:tags]
    end
    if options[:pool_id]
      locals[:link_params]["pool_id"] = options[:pool_id]
    end
    if options[:post_set_id]
      locals[:link_params]["post_set_id"] = options[:post_set_id]
    end

    locals[:tooltip] = "Rating: #{post.rating}\nID: #{post.id}\nDate: #{post.created_at}\nStatus: #{post.status}\nScore: #{post.score}\n\n#{post.tag_string}"

    locals[:cropped_url] = if FemboyFans.config.enable_image_cropping? && options[:show_cropped] && post.has_crop? && !CurrentUser.user.disable_cropped_thumbnails?
                             post.crop_file_url(CurrentUser.user)
                           elsif post.has_preview?
                             post.preview_file_url(CurrentUser.user)
                           else
                             post.file_url(CurrentUser.user)
                           end

    locals[:cropped_url] = FemboyFans.config.deleted_preview_url if post.deleteblocked?(CurrentUser.user)
    locals[:preview_url] = if post.deleteblocked?(CurrentUser.user)
                             FemboyFans.config.deleted_preview_url
                           elsif post.has_preview?
                             post.preview_file_url(CurrentUser.user)
                           else
                             post.file_url(CurrentUser.user)
                           end

    locals[:alt_text] = post.tag_string

    locals[:has_cropped] = post.has_crop?

    if options[:pool]
      locals[:pool] = options[:pool]
    else
      locals[:pool] = nil
    end

    locals[:width] = post.image_width
    locals[:height] = post.image_height

    if options[:similarity]
      locals[:similarity] = options[:similarity].round
    else
      locals[:similarity] = nil
    end

    if options[:size]
      locals[:size] = post.file_size
      locals[:file_ext] = post.file_ext
    else
      locals[:size] = nil
    end

    if options[:stats]
      locals[:stats] = true
    else
      locals[:stats] = false
    end

    ApplicationController.render(partial: "posts/partials/index/preview", locals: locals)
  end

  def self.preview_class(post, pool: nil, size: nil, similarity: nil, **options) # rubocop:disable Lint/UnusedMethodArgument
    klass = ["post-preview"]
    klass << "post-status-pending" if post.is_pending?
    klass << "post-status-flagged" if post.is_flagged?
    klass << "post-status-deleted" if post.is_deleted?
    klass << "post-status-has-parent" if post.parent_id
    klass << "post-status-has-children" if post.has_visible_children?(CurrentUser.user)
    klass << "post-rating-safe" if post.rating == "s"
    klass << "post-rating-questionable" if post.rating == "q"
    klass << "post-rating-explicit" if post.rating == "e"
    klass << "blacklistable" unless options[:no_blacklist]
    klass
  end

  def self.data_attributes(post, include_post: false)
    attributes = post.thumbnail_attributes(CurrentUser.user)
    attributes[:post] = post_attribute_attribute(post).to_json if include_post
    { data: attributes }
  end

  def self.post_attribute_attribute(post)
    {
      id:            post.id,
      created_at:    post.created_at,
      updated_at:    post.updated_at,
      fav_count:     post.fav_count,
      comment_count: post.visible_comment_count(CurrentUser.user),
      change_seq:    post.change_seq,
      uploader_id:   post.uploader_id,
      description:   post.description,
      flags:         {
        pending:       post.is_pending?,
        flagged:       post.is_flagged?,
        note_locked:   post.is_note_locked?,
        status_locked: post.is_status_locked?,
        rating_locked: post.is_rating_locked?,
        deleted:       post.is_deleted?,
        has_notes:     post.has_notes?,
      },
      score:         {
        up:    post.up_score,
        down:  post.down_score,
        total: post.score,
      },
      relationships: {
        parent_id:           post.parent_id,
        has_children:        post.has_children?,
        has_active_children: post.has_active_children?,
        children:            [],
      },
      pools:         post.pool_ids,
      file:          {
        width:  post.image_width,
        height: post.image_height,
        ext:    post.file_ext,
        size:   post.file_size,
        md5:    post.md5,
        url:    post.visible?(CurrentUser.user) ? post.file_url(CurrentUser.user) : nil,
      },
      variants:      post.variants(CurrentUser.user),
      sources:       post.source&.split('\n'),
      tags:          post.tag_string.split,
      locked_tags:   post.locked_tags&.split || [],
      is_favorited:  post.is_favorited?(CurrentUser.user),
      own_vote:      post.own_vote(CurrentUser.user),
    }
  end

  def image_attributes
    attributes = {
      :id        => "image",
      :class     => @post.display_class_for(CurrentUser.user),
      :alt       => humanized_essential_tag_string,
      "itemprop" => "contentUrl",
    }

    if @post.bg_color
      attributes["style"] = "background-color: ##{@post.bg_color};"
    end

    attributes
  end

  def initialize(post)
    @post = post
  end

  def tag_set_presenter
    @tag_set_presenter ||= TagSetPresenter.new(@post.tag_array)
  end

  def preview_html
    PostPresenter.preview(@post)
  end

  def humanized_tag_string
    @post.tag_string.split(/ /).slice(0, 25).join(", ").tr("_", " ")
  end

  def humanized_essential_tag_string
    @humanized_essential_tag_string ||= tag_set_presenter.humanized_essential_tag_string(default: "##{@post.id}")
  end

  def filename_for_download
    "#{humanized_essential_tag_string} - #{@post.md5}.#{@post.file_ext}"
  end

  def has_nav_links?(template)
    has_sequential_navigation?(template.params) || @post.has_active_pools? || @post.post_sets.owned_by(CurrentUser.user).any?
  end

  def has_sequential_navigation?(params)
    return false if TagQuery.has_metatag?(params[:q], "order")
    return false if params[:pool_id].present? || params[:post_set_id].present?
    true
  end

  def default_image_size(user)
    return "original" if @post.force_original_size?
    return "fit" if user.default_image_size == "large" && !@post.allow_sample_resize?
    user.default_image_size
  end
end
