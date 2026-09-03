# frozen_string_literal: true

# Pulls the default audio track out of a freshly-uploaded video into its own AudioTrack, so it
# sits alongside any suggested alternates on equal footing instead of being baked into the video
# file. No-ops for silent videos (nothing to extract) and if the post hasn't been created yet
# (retried via retry_on until it has - see UploadMediaAsset#extract_audio_track).
class AudioTrackExtractionJob < ApplicationJob
  queue_as(:variants)
  good_job_control_concurrency_with(total_limit: 1, key: -> { "AudioTrackExtractionJob-#{arguments[0]}" })
  retry_on(StandardError, attempts: 3)

  def perform(id)
    asset = UploadMediaAsset.find(id)
    raise(StandardError, "upload is still in progress") if asset.in_progress?
    raise(StandardError, "post not yet created") if asset.post.blank?
    return if asset.media_metadata.metadata["audio_streams"].blank?
    return if asset.post.audio_tracks.default.exists?(file_md5: asset.post.md5)

    uploader = asset.post.uploader.resolvable(asset.post.uploader_ip_addr)

    asset.open_file do |file|
      # Storing the media asset and creating its AudioTrack are wrapped in one transaction so
      # they succeed or fail together - if the process dies in between (e.g. an unattended
      # async job runner exiting mid-run, which is how post #896 ended up with a stored-but-
      # trackless media asset), nothing commits and a retry starts clean instead of leaving an
      # orphan behind.
      ActiveRecord::Base.transaction do
        audio_asset = AudioTrackMediaAsset.new(creator: uploader)
        # This bypasses the chunked-upload/finalize! lifecycle entirely (the file's already fully
        # in hand), so - like finalize! itself does right before invoking store - mark it active
        # first; otherwise MediaAsset's in-progress checksum-presence validation rejects it.
        audio_asset.status = "active"
        begin
          audio_asset.store!(uploader, file)
        rescue ActiveRecord::RecordInvalid
          # Reuse an already-stored media asset with this exact checksum rather than failing
          # forever on the collision - either a leftover orphan from a past interrupted run (see
          # above), or a legitimate content match with another post's identical audio.
          raise unless audio_asset.errors.of_kind?(:md5, :taken)
          audio_asset = AudioTrackMediaAsset.find_by!(md5: audio_asset.md5)
        end
        next unless audio_asset.active?
        next if audio_asset.audio_track.present?

        AudioTrack.create!(
          post:                    asset.post,
          audio_track_media_asset: audio_asset,
          creator:                 uploader,
          status:                  "approved",
          is_default:              true,
          label:                   "Original",
          is_system_generated:     true,
        )
      end
    end
  end
end
