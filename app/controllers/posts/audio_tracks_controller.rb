# frozen_string_literal: true

module Posts
  class AudioTracksController < ApplicationController
    before_action(:ensure_audio_tracks_enabled, only: %i[new create])
    respond_to(:html, :json)

    content_security_policy(only: %i[new]) do |p|
      p.img_src(:self, :data, :blob, "*")
      p.media_src(:self, :data, :blob, "*")
    end

    def index
      params[:search][:post_id] = params.delete(:post_id) if params.key?(:post_id)
      @audio_tracks = authorize(AudioTrack).html_includes(request, :post, :creator)
                                           .search_current(search_params(AudioTrack))
                                           .paginate(params[:page], limit: params[:limit])
      respond_with(@audio_tracks)
    end

    def new
      @post = Post.find(params[:post_id])
      @audio_track = authorize(@post.audio_tracks.new_with_current(:creator, permitted_attributes(AudioTrack)))
      respond_with(@audio_track)
    end

    def create
      @post = Post.find(params[:post_id])
      @audio_track = authorize(@post.audio_tracks.new_with_current(:creator, permitted_attributes(AudioTrack)))
      @audio_track.save
      if @audio_track.media_asset.expunged?
        return render(json: { success: false, reason: "invalid", message: "That file #{@audio_track.media_asset.status_message}" }, status: :precondition_failed)
      end
      if @audio_track.errors.none?
        flash.now[:notice] = "Audio track submitted for review"
      end
      respond_to do |format|
        format.json do
          return render(json: { success: false, message: @audio_track.errors.full_messages.join("; ") }, status: :precondition_failed) if @audio_track.errors.any?
          return render(json: { success: true, id: @audio_track.id, media_asset_id: @audio_track.media_asset_id }, status: :accepted) unless @audio_track.is_direct?
          render(json: { success: true, location: post_path(@post), id: @audio_track.id })
        end
      end
    end

    def approve
      @audio_track = authorize(AudioTrack.find(params[:id]))
      @audio_track.approve!(CurrentUser.user, set_default: params[:set_default])
      redirect_with_errors
    end

    def reject
      @audio_track = authorize(AudioTrack.find(params[:id]))
      @audio_track.reject!(CurrentUser.user, params.dig(:audio_track, :reason).presence || params[:reason].presence || "")
      redirect_with_errors
    end

    def set_default
      @audio_track = authorize(AudioTrack.find(params[:id]))
      @audio_track.set_default!(CurrentUser.user)
      redirect_with_errors
    end

    def destroy
      @audio_track = authorize(AudioTrack.find(params[:id]))
      @audio_track.destroy_with_current(:destroyer)

      respond_with(@audio_track) do |format|
        format.html { redirect_back_or_to(post_path(@audio_track.post_id)) }
        format.json
      end
    end

    private

    def redirect_with_errors
      respond_to do |format|
        format.html do
          flash[:notice] = @audio_track.errors.full_messages.join("; ") if @audio_track.errors.any?
          redirect_back_or_to(post_path(@audio_track.post_id))
        end
        format.json do
          return render(json: { success: false, message: @audio_track.errors.full_messages.join("; ") }, status: :precondition_failed) if @audio_track.errors.any?
          render(json: { success: true, id: @audio_track.id })
        end
      end
    end

    def ensure_audio_tracks_enabled
      access_denied if Security::Lockdown.uploads_disabled? || Security::Lockdown.audio_tracks_disabled? || CurrentUser.user.level < Security::Lockdown.uploads_min_level
    end
  end
end
