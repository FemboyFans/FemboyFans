# frozen_string_literal: true

class UploadMediaAsset < MediaAssetWithVariants
  self.deletion_supported = true
  has_one :upload
  has_one :post
  attr_accessor :is_replacement, :replacement_id

  # this is really ugly and it sucks, but it seems to work
  after_finalize :create_post, if: :file_later?
  after_finalize :regenerate_image_variants_and_data!, if: :file_later?
  after_finalize :regenerate_video_variants, if: -> { file_later? && is_video? }
  after_create :create_post, if: :file_now?
  after_create -> {
    regenerate_image_variants_and_data!
    save!
  }, if: :file_now?
  after_create :regenerate_video_variants, if: -> { file_now? && is_video? }

  scope :duplicate_relevant, -> { active.joins(:post).where.not("posts.id": nil) }

  def file_later?
    super && !is_replacement
  end

  # can be called multiple times
  def create_post
    upload&.create_post unless upload&.is_replacement
  end

  def link_to_duplicate
    return unless duplicate?
    return Routes.post_path(id: duplicate_post_id) if duplicate_post_id.present?
    return Routes.upload_media_assets_path(search: { id: duplicate_media_asset_id }) if duplicate_media_asset_id.present?
    nil
  end

  def duplicate_post_id
    return unless duplicate? && status_message.present?
    @duplicate_post_id ||= status_message[/post #(\d+)/, 1]&.to_i
  end

  def duplicate_media_asset_id
    return unless duplicate? && status_message.present?
    @duplicate_media_asset_id ||= status_message[/media asset #(\d+)/, 1]&.to_i
  end

  module StorageMethods
    def path_prefix
      FemboyFans.config.post_path_prefix
    end

    def protected_path_prefix
      FemboyFans.config.protected_path_prefix
    end
  end

  module VariantMethods
    def variants
      return @variants if instance_variable_defined?(:@variants)
      rescale = MediaAsset::Rescale.new(width: image_width, height: image_height, method: :none)
      format = is_image? ? :image : :video
      @variants = super(Variant)
      if is_image?
        FemboyFans.config.image_variants.each do |name, options|
          next if name == "large" && !supports_large?
          @variants << Variant.new(self, name, format, "webp", options) if variant_valid?(options)
        end
      elsif is_video?
        FemboyFans.config.video_image_variants.each do |name, options|
          @variants << Variant.new(self, name, format, "webp", options) if variant_valid?(options)
        end
        @variants << Variant.new(self, :original, format, alt_file_ext, rescale)
        FemboyFans.config.video_variants.each do |name, options|
          @variants += [Variant.new(self, name, format, file_ext, options), Variant.new(self, name, format, alt_file_ext, options)] if variant_valid?(options)
        end
      end
      @variants
    end

    def alt_file_ext
      return unless is_video?
      file_ext == "webm" ? "mp4" : "webm"
    end

    def regenerate_variants
      UploadMediaAssetVariantsJob.perform_later(id)
    end

    def regenerate_variants!(file = self.file)
      variants = self.variants.without(original)
      if file
        variants.each { |variant| variant.store!(file) }
      else
        open_file do |rfile|
          variants.each { |variant| variant.store!(rfile) }
        end
      end
      update_variants_data
      true
    end

    def generate_variants_after_finalize
      # intentional no-op, handled above
    end

    def regenerate_image_variants
      UploadMediaAssetImageVariantsJob.perform_later(id)
    end

    def regenerate_image_variants!(file = self.file)
      variants = image_variants.without(original)

      if file
        variants.each { |variant| variant.store!(file) }
      else
        open_file do |rfile|
          variants.each { |variant| variant.store!(rfile) }
        end
      end
      true
    end

    def regenerate_image_variants_and_data!(file = self.file)
      regenerate_image_variants!(file)
      update_variants_partial_data(image_variants.without(original))
    end

    def regenerate_video_variants
      UploadMediaAssetVideoVariantsJob.perform_later(id)
    end

    def regenerate_video_variants!(file = self.file)
      variants = video_variants.without(original)

      if file
        variants.each { |variant| variant.store!(file) }
      else
        open_file do |rfile|
          variants.each { |variant| variant.store!(rfile) }
        end
      end
      true
    end
  end

  module SearchMethods
    def search(params)
      q = super
      q = q.joins(:post).where("posts.id": params[:post_id]) if params[:post_id].present?
      q = q.joins(:upload).where("uploads.id": params[:upload_id]) if params[:upload_id].present?
      q
    end
  end

  include StorageMethods
  include VariantMethods
  extend SearchMethods

  class Variant < MediaAssetWithVariants::Variant
    def convert_file(original_file, &block)
      raise(ArgumentError, "block is required") if block.nil?
      handle = ->(file) {
        set_data(file)
        block.call(file)
      }
      return handle.call(original_file) if type == :original && (!is_video? || ext == file_ext)
      if is_video? # original
        if video? # variant
          convert_video(original_file, &handle)
        else
          convert_image_for_video(original_file, &handle)
        end
      else
        convert_image(original_file, &handle)
      end
    end

    def convert_video(original_file, &)
      width, height = scaled_dimensions
      method = ext == "webm" ? :video_scale_options_webm : :video_scale_options_mp4
      file = Tempfile.new(%W[video-sample .#{ext}], binmode: true)
      args = [*FemboyFans.config.public_send(method, width, height, file.path), "-y", "-i", original_file.path]
      stdout, stderr, status = Open3.capture3(FemboyFans.config.ffmpeg_path, *args)

      unless status == 0
        logger.warn("[FFMPEG TRANSCODE STDOUT] #{stdout.chomp}")
        logger.warn("[FFMPEG TRANSCODE STDERR] #{stderr.chomp}")
        raise(StandardError, "unable to transcode files\n#{stdout.chomp}\n\n#{stderr.chomp}")
      end

      file.tap(&).close!
    end

    def convert_image_for_video(original_file, &)
      return crop_video(original_file, &) if type == :crop
      VideoResizer.sample(original_file.path, width: width, height: height, frame: post&.thumbnail_frame).tap(&).close!
    end

    def crop_video(original_file, &)
      VideoResizer.crop(original_file.path, width, height, frame: post&.thumbnail_frame).tap(&).close!
    end

    def convert_image(original_file, &)
      return crop_image(original_file, &) if type == :crop
      ImageResizer.resize(original_file, width, height).tap(&).close!
    end

    def crop_image(original_file, &)
      ImageResizer.crop(original_file, width, height, 90).tap(&).close!
    end
  end

  def large_width
    find_variant(:large)&.width
  end

  def preview_width
    find_variant(:preview)&.width
  end

  def supports_large?
    return true if is_video?
    return false if is_gif? || is_animated_png?
    is_image? && image_width.present? && image_width > FemboyFans.config.large_image_width
  end

  # reset to an empty shell, for use with replacements
  def reset
    self.status = "pending"
    self.checksum = nil
    self.md5 = nil
    self.file_ext = nil
    self.file_size = nil
    self.image_width = nil
    self.image_height = nil
    self.duration = nil
    self.framecount = nil
    self.pixel_hash = nil
    self.last_chunk_id = 0
    self.generated_variants = []
    self.variants_data = []
  end

  def replace_file(file, checksum)
    reset
    self.checksum = checksum
    self.is_replacement = true
    append_all!(file, save: false)
    regenerate_image_variants!
    update_variants_partial_data(image_variants.without(original))
    save!
    post&.update_iqdb_async
    post&.update_index
    self.is_replacement = false
    regenerate_video_variants if is_video?
    md5 == checksum
  end

  def self.available_includes
    %i[creator upload]
  end
end
