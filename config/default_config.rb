# frozen_string_literal: true

module FemboyFans
  class Configuration
    def version
      GitHelper.instance.origin.short_commit
    end

    def app_name
      "Femboy Fans"
    end

    def app_url
      "https://#{domain}"
    end

    def canonical_app_name
      app_name
    end

    def canonical_app_url
      app_url
    end

    def description
      "Your one-stop shop for femboy furries."
    end

    def domain
      "femboy.fan"
    end

    def cdn_domain
      "static.femboy.fan"
    end

    def server_name
      `hostname`[..-2]
    end

    # Force rating:s on this version of the site.
    def safe_mode?
      false
    end

    def user_approvals_enabled?
      true
    end

    # The canonical hostname of the site.
    def hostname
      Socket.gethostname
    end

    def source_code_url
      "https://github.com/FemboyFans/FemboyFans"
    end

    def local_source_code_url
      "https://github.com/FemboyFans/FemboyFans"
    end

    # Stripped of any special characters.
    def safe_app_name
      app_name.gsub(/[^a-zA-Z0-9_-]/, "_")
    end

    def anonymous_user_name
      "Anonymous"
    end

    def anonymous_user
      user = User.new(name: anonymous_user_name, level: User::Levels::ANONYMOUS, created_at: Time.now)
      user.readonly!.freeze
      user
    end

    def system_user_name
      "System"
    end

    def system_user
      User.find_or_create_by!(name: system_user_name, level: User::Levels::SYSTEM) do |user|
        user.email                = "system@#{domain}"
        user.can_approve_posts    = true
        user.unrestricted_uploads = true
        user.email_verified       = true
      end
    end

    # Set the default level, permissions, and other settings for new users here.
    def customize_new_user(user)
      user.blacklisted_tags           = Config.instance.default_blacklist
      user.comment_threshold          = -10
      user.enable_autocomplete        = true
      user.enable_keyboard_navigation = true
      user.per_page                   = Config.instance.records_per_page
      user.style_usernames            = true
      user.move_related_thumbnails    = true
      user.enable_hover_zoom          = true
      user.hover_zoom_shift           = true
      user.hover_zoom_sticky_shift    = true
      user.go_to_recent_forum_post    = true
      user.forum_unread_bubble        = true
      user.upload_notifications       = User.upload_notifications_options
      user.email_verified             = !Config.instance.enable_email_verification?
      user.level                      = User::Levels::RESTRICTED if user_approvals_enabled? && user.level == User::Levels::MEMBER
    end

    # This allows using statically linked copies of ffmpeg in non default locations. Not universally supported across
    # the codebase at this time.
    def ffmpeg_path
      "/usr/bin/ffmpeg"
    end

    def protected_path_prefix
      "deleted/"
    end

    def protected_file_secret
      "abc123"
    end

    def post_path_prefix
      "posts/"
    end

    def replacement_path_prefix
      "replacements/"
    end

    def mascot_path_prefix
      "mascots/"
    end

    def replacement_file_secret
      "abc123"
    end

    def deleted_preview_url
      "/images/deleted-preview.png"
    end

    # List of memcached servers
    def memcached_servers
      %w[127.0.0.1:11211]
    end

    def disable_throttles?
      false
    end

    def disable_age_checks?
      false
    end

    def disable_cache_store?
      false
    end

    def remember_key
      "abc123"
    end

    # If the user can request a bulk update request containing a nuke instruction
    def can_bur_nuke?(user)
      user.is_admin?
    end

    # Return true if the given tag shouldn't count against the user's tag search limit.
    def is_unlimited_tag?(tag)
      !!(tag =~ /\A(-?status:deleted|rating:s.*|limit:.+)\z/i)
    end

    def discord_site
    end

    def discord_secret
    end

    # Permanently redirect all HTTP requests to HTTPS.
    #
    # https://en.wikipedia.org/wiki/HTTP_Strict_Transport_Security
    # http://api.rubyonrails.org/classes/ActionDispatch/SSL.html
    def ssl_options
      {
        redirect: { exclude: ->(request) { request.subdomain == "insecure" } },
        hsts:     {
          expires:    1.year,
          preload:    true,
          subdomains: false,
        },
      }
    end

    # hierarchical is in app/models/media_asset.rb as a constant now
    # The method to use for storing image files.
    def storage_manager
      # Store files on the local filesystem.
      # base_dir - where to store files (default: under public/data)
      # base_url - where to serve files from (default: http://#{hostname}/data)
      # hierarchical: false - store files in a single directory
      # hierarchical: true - store files in a hierarchical directory structure, based on the MD5 hash
      StorageManager::Local.new(base_dir: Rails.public_path.join("data").to_s, hierarchical: true)
      # StorageManager::Ftp.new(ftp_hostname, ftp_port, ftp_username, ftp_password, base_dir: "", base_path: "", base_url: "https://static.femboy.fan", hierarchical: true)

      # Select the storage method based on the post's id and type (preview, large, or original).
      # StorageManager::Hybrid.new do |id, md5, file_ext, type|
      #   if type.in?([:large, :original]) && id.in?(0..850_000)
      #     StorageManager::Local.new(base_dir: "/path/to/files", hierarchical: true)
      #   else
      #     StorageManager::Local.new(base_dir: "/path/to/files", hierarchical: true)
      #   end
      # end
    end

    # The method to use for backing up image files.
    def backup_storage_manager
      # Don't perform any backups.
      StorageManager::Null.new

      # Backup files to /mnt/backup on the local filesystem.
      # StorageManager::Local.new(base_dir: "/mnt/backup", hierarchical: false)
    end

    def flag_reasons
      [
        {
          name:                "uploading_guidelines",
          reason:              "Does not meet the \"uploading guidelines\":/help/uploading_guidelines",
          text:                "This post fails to meet the site's standards, be it for artistic worth, image quality, relevancy, or something else.\nKeep in mind that your personal preferences have no bearing on this. If you find the content of a post objectionable, simply \"blacklist\":/help/blacklisting it.",
          require_explanation: true,
        },
        {
          name:   "dnp_artist",
          reason: "The artist of this post is on the \"avoid posting list\":/static/avoid_posting",
          text:   "Certain artists have requested that their work is not to be published on this site, and were granted [[avoid_posting|Do Not Post]] status.\nSometimes, that status comes with conditions; see [[conditional_dnp]] for more information",
        },
        {
          name:   "pay_content",
          reason: "Paysite, commercial, or subscription content",
          text:   "We do not host paysite or commercial that is under 1 year old.",
        },
        {
          name:                "trace",
          reason:              "Trace of another artist's work",
          text:                "Images traced from other artists' artwork are not accepted on this site. Referencing from something is fine, but outright copying someone else's work is not.\nPlease, leave more information in the comments, or simply add the original artwork as the posts's parent if it's hosted on this site.",
          require_explanation: true,
        },
        {
          name:   "previously_deleted",
          reason: "Previously deleted",
          text:   "Posts usually get removed for a good reason, and reuploading of deleted content is not acceptable.\nPlease, leave more information in the comments, or simply add the original post as this post's parent.",
        },
        {
          name:   "real_porn",
          reason: "Real-life pornography",
          text:   "Posts featuring real-life pornography are not acceptable on this site.",
        },
        {
          name:                "corrupt",
          reason:              "File is either corrupted, broken, or otherwise does not work",
          text:                "Something about this post does not work quite right. This may be a broken video, or a corrupted image.\nEither way, in order to avoid confusion, please explain the situation in the comments.",
          require_explanation: true,
        },
        {
          name:   "inferior",
          reason: "Duplicate or inferior version of another post",
          text:   "A superior version of this post already exists on the site.\nThis may include images with better visual quality (larger, less compressed), but may also feature \"fixed\" versions, with visual mistakes accounted for by the artist.\nNote that edits and alternate versions do not fall under this category.",
          parent: true,
        },
      ]
    end

    # Any custom code you want to insert into the default layout without
    # having to modify the templates.
    def custom_html_header_content
      nil
    end

    def can_user_see_post?(user, post)
      # TODO: appealed posts should be visible, but this makes it far too easy to get the contents of deleted posts at a moments notice
      return true if user.is_staff? # || post.is_appealed?
      !post.is_deleted?
    end

    def user_needs_login_for_post?(_post)
      false
    end

    def select_posts_visible_to_user(user, posts)
      posts.select { |x| can_user_see_post?(user, x) }
    end

    # TODO: move to dynamic config
    def enable_autotagging?
      true
    end

    # The default headers to be sent with outgoing http requests. Some external
    # services will fail if you don't set a valid User-Agent.
    def http_headers
      {
        user_agent: "#{safe_app_name}/#{version} (https://github.com/FemboyFans/FemboyFans)",
      }
    end

    # https://lostisland.github.io/faraday/#/customization/connection-options
    def faraday_options
      {
        request: {
          timeout:      10,
          open_timeout: 10,
        },
        headers: http_headers,
      }
    end

    # you should override this
    def email_key
      "zDMSATq0W3hmA5p3rKTgD"
    end

    def mailgun_api_key
    end

    def mailgun_domain
    end

    def mail_from_addr
      "noreply@localhost"
    end

    def smtp_address
    end

    def smtp_port
    end

    def smtp_domain
    end

    def smtp_username
    end

    def smtp_password
    end

    def smtp_authentication
    end

    def smtp_tls
    end

    def recommender_server
    end

    def iqdb_server
    end

    def elasticsearch_host
    end

    # Use a recaptcha on the signup page to protect against spambots creating new accounts.
    # https://developers.google.com/recaptcha/intro
    def enable_recaptcha?
      Rails.env.production? && FemboyFans.config.recaptcha_site_key.present? && FemboyFans.config.recaptcha_secret_key.present?
    end

    def recaptcha_site_key
    end

    def recaptcha_secret_key
    end

    def enable_image_cropping?
      true
    end

    def redis_url
    end

    def clickhouse_url
      "http://clickhouse:8123"
    end

    def bypass_upload_whitelist?(user)
      user.is_admin? || user == User.system
    end

    def large_image_width
      image_variants["large"]&.width || raise("missing large image variant")
    end

    # Additional video samples will be generated in these dimensions if it makes sense to do so
    # They will be available as additional scale options on applicable posts in the order they appear here
    def video_variants
      {
        "720p" => MediaAsset::Rescale.new(width: 1280, height: 720, method: :scaled),
        "480p" => MediaAsset::Rescale.new(width: 640, height: 480, method: :scaled),
      }
    end

    def video_image_variants
      {
        "crop"    => MediaAsset::Rescale.new(width: 300, height: 300, method: :exact),
        "preview" => MediaAsset::Rescale.new(width: 300, height: nil, method: :scaled), # thumbnail, small
        "large"   => MediaAsset::Rescale.new(width: nil, height: nil, method: :scaled), # sample
      }
    end

    def image_variants
      {
        "crop"    => MediaAsset::Rescale.new(width: 300, height: 300, method: :exact),
        "preview" => MediaAsset::Rescale.new(width: 300, height: nil, method: :scaled), # thumbnail, small
        "large"   => MediaAsset::Rescale.new(width: 850, height: nil, method: :scaled), # sample, width is used to determine resizing
      }
    end

    def variant_location(variant, _file_ext)
      variant = variant.to_s
      return :none if variant == "original"
      return :path if %w[720p 480p crop preview large].include?(variant)
      return :file if %w[thumb].include?(variant)
      # return :file if %w[720p 480p].include?(variant)
      # return :path if %w[crop preview large].include?(variant)
      Rails.logger.warn("[variant_location]: Unknown variant #{variant}")
      :none
    end

    def video_scale_options_webm(width, height, file_path)
      [
        "-c:v",
        "libvpx-vp9",
        "-pix_fmt",
        "yuv420p",
        "-deadline",
        "good",
        "-cpu-used",
        "5", # 4+ disable a bunch of rate estimation features, but seems to save reasonable CPU time without large quality drop
        "-auto-alt-ref",
        "0",
        "-qmin",
        "20",
        "-qmax",
        "42",
        "-crf",
        "35",
        "-b:v",
        "3M",
        "-vf",
        "scale=w=#{width}:h=#{height}",
        "-threads",
        (Etc.nprocessors * 0.7).to_i.to_s,
        "-row-mt",
        "1",
        "-max_muxing_queue_size",
        "4096",
        "-slices",
        "8",
        "-c:a",
        "libopus",
        "-b:a",
        "96k",
        "-map_metadata",
        "-1",
        "-metadata",
        'title="femboy.fan_preview_quality_conversion,_visit_site_for_full_quality_download"',
        file_path,
      ]
    end

    def video_scale_options_mp4(width, height, file_path)
      [
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-profile:v",
        "main",
        "-preset",
        "fast",
        "-crf",
        "27",
        "-b:v",
        "3M",
        "-vf",
        "scale=w=#{width}:h=#{height}",
        "-threads",
        (Etc.nprocessors * 0.7).to_i.to_s,
        "-max_muxing_queue_size",
        "4096",
        "-c:a",
        "aac",
        "-b:a",
        "128k",
        "-map_metadata",
        "-1",
        "-metadata",
        'title="femboy.fan_preview_quality_conversion,_visit_site_for_full_quality_download"',
        "-movflags",
        "+faststart",
        file_path,
      ]
    end

    def replacement_thumbnail_width
      300
    end

    def janitor_reports_discord_webhook_url
      nil
    end

    def moderator_stats_discord_webhook_url
      nil
    end

    def aibur_stats_discord_webhook_url
      nil
    end

    def discord_webhook_url
      nil
    end

    def ftp_hostname
    end

    def ftp_port
    end

    def ftp_username
    end

    def ftp_password
    end

    def ticket_quick_response_buttons
      [
        { name: "Handled", text: "Handled, thank you." },
        { name: "Reviewed", text: "Reviewed, thank you." },
        { name: "NAT", text: "Reviewed, no action taken." },
        { name: "Closed", text: "Ticket closed." },
        { name: "Dismissed", text: "Ticket dismissed." },
        { name: "Old", text: "That comment is from N years ago.\nWe do not punish people for comments older than 3 months." },
        { name: "Reply", text: "I believe that you tried to reply to a comment, but reported it instead.\nPlease, be more careful in the future." },
        { name: "Already", text: "User already received a record for that message." },
        { name: "Banned", text: "This user is already banned." },
        { name: "Blacklist", text: "If you find the contents of that post objectionable, \"blacklist\":/help/blacklisting it." },
        { name: "Takedown", text: "Artists and character owners may request a takedown \"here\":/static/takedown.\nWe do not accept third party takedowns." },
      ]
    end

    def reports_enabled?
      FemboyFans.config.reports_server.present?
    end

    def reports_server
    end

    def reports_server_internal
      FemboyFans.config.reports_server
    end

    def report_key
    end

    def rakismet_key
    end

    def rakismet_url
      "https://#{hostname}"
    end

    def show_tag_scripting?(user)
      user.is_trusted?
    end

    def show_backtrace?(user, _backtrace)
      return true if Rails.env.development?
      user.is_janitor?
    end

    def max_concurrency
      Concurrent.available_processor_count.to_i.clamp(1..)
    end
  end

  class EnvironmentConfiguration
    def custom_configuration
      @custom_configuration ||= CustomConfiguration.new
    end

    def env_to_boolean(method, var)
      is_boolean = method.to_s.end_with?("?")
      return true if is_boolean && var.truthy?
      return false if is_boolean && var.falsy?
      var
    end

    def method_missing(method, *)
      var = ENV.fetch("FEMBOYFANS_#{method.to_s.upcase.chomp('?')}", nil)

      if var.present?
        env_to_boolean(method, var)
      else
        custom_configuration.send(method, *)
      end
    end
  end

  def config
    @config ||= EnvironmentConfiguration.new
  end

  module_function(:config)
end
