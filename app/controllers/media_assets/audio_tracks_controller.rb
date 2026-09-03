# frozen_string_literal: true

module MediaAssets
  class AudioTracksController < BaseController
    def finalize
      @asset = authorize(asset_class.find(params[:id]))
      @asset.finalize!
      @asset.reload_audio_track
      return respond_with(@asset) if @asset.errors.any?
      return render_expected_error(422, @asset.pretty_status) if @asset.failed?
      return respond_with(@asset) if @asset.audio_track.blank?
      render(json: { success: true, location: post_path(@asset.audio_track.post_id), post_id: @asset.audio_track.post_id, audio_track_id: @asset.audio_track.id })
    end

    protected

    def asset_class
      AudioTrackMediaAsset
    end
  end
end
