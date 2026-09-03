# frozen_string_literal: true

class AudioTrackMediaAsset < MediaAsset
  self.requires_dimensions = false
  has_one(:audio_track)
  after_finalize(:update_audio_track)

  # The parent AudioTrack starts life as "uploading" (see db/migrate/*_create_audio_tracks.rb) so
  # it doesn't show up in the review queue while its file is still being chunk-uploaded - once
  # this asset finalizes, flip it to "pending" so a mod can actually see and act on it. Mirrors
  # PostReplacementMediaAsset#update_post_replacement.
  def update_audio_track
    return unless audio_track&.valid?
    audio_track.pending! if audio_track.uploading?
  end

  module StorageMethods
    def path_prefix
      GayFurCity.config.audio_track_path_prefix
    end

    def protected_path_prefix
      GayFurCity.config.protected_path_prefix
    end

    def is_protected?
      audio_track&.post&.protect_file? || deleted?
    end

    # Whatever gets uploaded (an existing .m4a, or an mp3/wav/video/etc a user suggests) is
    # always normalized to AAC/.m4a first - AudioTrackMediaAsset only ever stores that one
    # format, so playback/sync code never has to deal with multiple audio containers.
    def store(user, file = self.file)
      transcoded = AudioExtractor.extract(file.path)
    rescue StandardError => e
      self.status = "failed"
      self.status_message = "could not extract audio: #{e.message}"
      self.updater = user
    else
      super(user, transcoded)
    end
  end

  module FileMethods
    def validate_file
      ext = self.class.file_header_to_file_ext(file.path)
      unless ext == "m4a"
        errors.add(:file_ext, "#{ext} is invalid (only audio/video files that can be converted to AAC are allowed)")
        throw(:abort)
      end
      if file.size <= 16
        errors.add(:file_size, "is too small")
      end
      duration = self.class.audio_metadata(file.path)[:duration]
      errors.add(:base, "could not determine audio duration") if duration.to_f <= 0
    end
  end

  include(StorageMethods)
  include(FileMethods)

  def self.available_includes
    %i[creator audio_track]
  end
end
