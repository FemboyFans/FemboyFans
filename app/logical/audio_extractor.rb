# frozen_string_literal: true

# Pulls the audio out of a file (video or audio) into a standalone AAC/.m4a Tempfile - used both
# to auto-extract a video upload's default audio track, and to normalize a user-suggested audio
# track upload to the one format AudioTrackMediaAsset accepts (see AudioTrackMediaAsset#store).
# -vn drops any video stream, so this works unmodified for a video input or a plain audio input.
module AudioExtractor
  module_function

  def extract(file_path)
    output_file = Tempfile.new(%w[audio-track .m4a], binmode: true)
    args = [*GayFurCity.config.audio.scale_options_aac(output_file.path), "-y", "-i", file_path]
    stdout, stderr, status = Open3.capture3(GayFurCity.config.ffmpeg_path, *args)

    unless status == 0
      Rails.logger.warn("[FFMPEG AUDIO EXTRACT STDOUT] #{stdout.chomp!}")
      Rails.logger.warn("[FFMPEG AUDIO EXTRACT STDERR] #{stderr.chomp!}")
      raise(StandardError, "unable to extract audio")
    end
    output_file
  end
end
