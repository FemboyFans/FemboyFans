# frozen_string_literal: true

module FileMethods
  def is_image?
    Post::IMAGE_EXTENSIONS.include?(file_ext)
  end

  def is_png?
    file_ext == "png"
  end

  def is_jpg?
    file_ext == "jpg"
  end

  def is_gif?
    file_ext == "gif"
  end

  def is_webp?
    file_ext == "webp"
  end

  def is_webm?
    file_ext == "webm"
  end

  def is_mp4?
    file_ext == "mp4"
  end

  def is_video?
    Post::VIDEO_EXTENSIONS.include?(file_ext)
  end

  def is_animated_png?(file_path)
    is_png? && ApngInspector.new(file_path).inspect!.animated?
  end

  def is_animated_gif?(file_path)
    return false unless is_gif?

    # Check whether the gif has multiple frames by trying to load the second frame.
    result = begin
      Vips::Image.gifload(file_path, page: 1)
    rescue StandardError
      $ERROR_INFO
    end
    if result.is_a?(Vips::Image)
      true
    elsif result.is_a?(Vips::Error) && result.message =~ /bad page number/
      false
    else
      raise(result)
    end
  end

  def is_ai_generated?(file_path)
    return false unless is_image?

    image = Vips::Image.new_from_file(file_path)
    fetch = ->(key) do
      value = image.get(key)
      value.encode("ASCII", invalid: :replace, undef: :replace).gsub("\u0000", "")
    rescue Vips::Error
      ""
    end

    return true if fetch.call("png-comment-0-parameters").present?
    return true if fetch.call("png-comment-0-Dream").present?
    return true if fetch.call("exif-ifd0-Software").include?("NovelAI") || fetch.call("png-comment-2-Software").include?("NovelAI")
    return true if ["exif-ifd0-ImageDescription", "exif-ifd2-UserComment", "png-comment-4-Comment"].any? { |field| fetch.call(field).include?('"sampler": "') }
    exif_data = fetch.call("exif-data")
    return true if ["Model hash", "OpenAI", "NovelAI"].any? { |marker| exif_data.include?(marker) }
    false
  end

  def file_header_to_file_ext(file_path)
    UploadService::Utils.file_header_to_file_ext(file_path)
  end

  def calculate_dimensions(file_path)
    UploadService::Utils.calculate_dimensions(file_path)
  end

  def video(file_path)
    @video ||= FFMPEG::Movie.new(file_path)
  end

  def video_duration(file_path)
    return video(file_path).duration if is_video? && video(file_path).duration
    nil
  end

  def video_framecount(file_path)
    return nil unless is_video?
    video = video(file_path)
    return nil unless video.duration && video.frame_rate
    (video.frame_rate * video.duration).ceil
  end

  def is_corrupt?(file_path)
    image = Vips::Image.new_from_file(file_path, fail: true)
    image.stats
    false
  rescue StandardError
    true
  end
end
