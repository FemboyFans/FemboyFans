<template>
  <div
    class="video-player"
    ref="container"
    :class="{ 'controls-idle': !controlsVisible && isPlaying }"
    @mousemove="wakeControls"
    @mouseleave="onMouseLeave"
  >
    <video
      id="image"
      ref="video"
      :class="videoClass"
      :poster="poster"
      :loop="repeatEnabled"
      preload="auto"
      playsinline
      @click="togglePlay"
      @play="onPlay"
      @pause="onPause"
      @timeupdate="onTimeUpdate"
      @durationchange="onDurationChange"
      @loadedmetadata="onDurationChange"
      @progress="onProgress"
      @waiting="isBuffering = true"
      @playing="isBuffering = false"
    >
      <source v-for="source in sources" :key="source.type" :src="source.src" :type="source.type">
    </video>

    <audio v-if="hasAudioTracks" ref="audio" preload="auto" :loop="repeatEnabled"></audio>

    <div class="video-controls">
      <div
        class="video-seek"
        ref="seek"
        @pointerdown="startSeek"
      >
        <div class="video-seek-track">
          <div class="video-seek-buffered" :style="{ width: bufferedPercent + '%' }"></div>
          <div class="video-seek-played" :style="{ width: playedPercent + '%' }"></div>
        </div>
        <div class="video-seek-handle" :style="{ left: playedPercent + '%' }"></div>
      </div>

      <div class="video-controls-row">
        <button type="button" class="video-btn video-play-pause" :title="isPlaying ? 'Pause' : 'Play'" @click="togglePlay">
          <i :class="isPlaying ? 'fa-solid fa-pause' : 'fa-solid fa-play'"></i>
        </button>

        <div class="video-volume">
          <button
            type="button"
            class="video-btn"
            :title="showVolumeControl ? (muted ? 'Unmute' : 'Mute') : 'No audio'"
            :disabled="!showVolumeControl"
            @click="toggleMute"
          >
            <i :class="volumeIconClass"></i>
          </button>
          <input
            v-if="showVolumeControl"
            type="range"
            class="video-volume-slider"
            min="0"
            max="1"
            step="0.01"
            v-model.number="volume"
          >
        </div>

        <div class="video-time">{{ formatTime(currentTime) }} / {{ formatTime(duration) }}</div>

        <div class="video-spacer"></div>

        <select
          v-if="hasMultipleAudioTracks"
          class="video-audio-track-select"
          v-model="selectedTrackId"
          title="Audio track"
          v-memo="[selectedTrackId, audioTracks]"
          @focus="onTrackSelectFocus"
          @blur="onTrackSelectBlur"
        >
          <option v-for="track in audioTracks" :key="track.id" :value="track.id">{{ track.label }}</option>
        </select>

        <button type="button" class="video-btn" :class="{ active: repeatEnabled }" :title="repeatEnabled ? 'Disable repeat' : 'Enable repeat'" @click="toggleRepeat">
          <i class="fa-solid fa-repeat"></i>
        </button>

        <button type="button" class="video-btn" :title="isFullscreen ? 'Exit fullscreen' : 'Fullscreen'" @click="toggleFullscreen">
          <i :class="isFullscreen ? 'fa-solid fa-compress' : 'fa-solid fa-expand'"></i>
        </button>
      </div>
    </div>
  </div>
</template>

<script>
const VOLUME_KEY = "video_volume";
const MUTED_KEY = "video_muted";
const REPEAT_KEY = "video_repeat";
// Buffering/network stalls drift the video and its separate audio track apart over time -
// resync if they drift by more than a third of a second.
const MAX_DRIFT = 0.3;

export default {
  props: {
    sources: { type: Array, required: true },
    poster: { type: String, default: null },
    videoClass: { type: String, default: "" },
    audioTracks: { type: Array, default: () => [] },
  },
  data () {
    const savedVolume = parseFloat(localStorage.getItem(VOLUME_KEY));
    const defaultTrack = this.audioTracks.find((track) => track.is_default) || this.audioTracks[0];
    return {
      isPlaying: false,
      isBuffering: false,
      currentTime: 0,
      duration: 0,
      buffered: 0,
      volume: Number.isFinite(savedVolume) ? savedVolume : 1.0,
      muted: localStorage.getItem(MUTED_KEY) === "true",
      repeatEnabled: localStorage.getItem(REPEAT_KEY) === "true",
      // Optimistic until proven otherwise - most videos have audio, and the detection below
      // can take a moment (or, on Safari, a second of playback) to confirm silence.
      nativeAudioDetected: true,
      selectedTrackId: defaultTrack ? defaultTrack.id : null,
      isFullscreen: false,
      controlsVisible: true,
      seeking: false,
      hideControlsTimer: null,
      // The audio-track <select>'s open dropdown is a native popup outside our DOM/CSS control -
      // while it (or anything else in the controls bar) has focus, the controls must stay
      // visible even if the mouse has moved off the player, or the popup is left looking
      // detached from a control bar that's faded away underneath it.
      controlsFocused: false,
      mouseOverPlayer: true,
    };
  },
  computed: {
    hasAudioTracks () {
      return this.audioTracks.length > 0;
    },
    hasMultipleAudioTracks () {
      return this.audioTracks.length > 1;
    },
    // A selected audio track was uploaded as an audio file, so it always has sound - only the
    // video's own embedded audio (used when there's no track) needs the silence check.
    showVolumeControl () {
      return this.hasAudioTracks || this.nativeAudioDetected;
    },
    playedPercent () {
      if (!this.duration) return 0;
      return Math.min(100, (this.currentTime / this.duration) * 100);
    },
    bufferedPercent () {
      if (!this.duration) return 0;
      return Math.min(100, (this.buffered / this.duration) * 100);
    },
    volumeIconClass () {
      if (!this.showVolumeControl || this.muted || this.volume <= 0) return "fa-solid fa-volume-xmark";
      if (this.volume < 0.5) return "fa-solid fa-volume-low";
      return "fa-solid fa-volume-high";
    },
    // The element that actually carries audible sound - the separate <audio> track when one
    // exists, otherwise the video's own embedded audio.
    audioTarget () {
      return this.hasAudioTracks ? this.$refs.audio : this.$refs.video;
    },
    selectedTrack () {
      return this.audioTracks.find((track) => track.id === this.selectedTrackId);
    },
  },
  watch: {
    volume (value) {
      if (value > 0 && this.muted) this.muted = false;
      this.applyVolume();
      localStorage.setItem(VOLUME_KEY, value);
    },
    muted (value) {
      this.applyVolume();
      localStorage.setItem(MUTED_KEY, value ? "true" : "false");
    },
    selectedTrackId () {
      this.changeTrack();
    },
    repeatEnabled (value) {
      localStorage.setItem(REPEAT_KEY, value ? "true" : "false");
    },
  },
  mounted () {
    const video = this.$refs.video;

    // The audio track plays through a separate <audio> element, not the video's own embedded
    // audio - so the video is permanently silent. This is the only place that ever touches
    // video.muted; nothing else can toggle it (there's no native UI exposing it anymore), so
    // there's nothing to fight and nothing to keep back in sync.
    if (this.hasAudioTracks) {
      video.muted = true;
      const audio = this.$refs.audio;
      audio.src = this.selectedTrack.url;
      audio.loop = true;
    }
    this.applyVolume();

    document.addEventListener("fullscreenchange", this.onFullscreenChange);
    window.addEventListener("pointerup", this.stopSeek);
    window.addEventListener("pointermove", this.onSeekMove);
  },
  beforeUnmount () {
    document.removeEventListener("fullscreenchange", this.onFullscreenChange);
    window.removeEventListener("pointerup", this.stopSeek);
    window.removeEventListener("pointermove", this.onSeekMove);
    clearTimeout(this.hideControlsTimer);
  },
  methods: {
    applyVolume () {
      const target = this.audioTarget;
      if (!target) return;
      target.volume = this.volume;
      target.muted = this.muted;
    },
    togglePlay () {
      const video = this.$refs.video;
      if (video.paused) video.play().catch(() => {});
      else video.pause();
    },
    onPlay () {
      this.isPlaying = true;
      if (this.hasAudioTracks) {
        const audio = this.$refs.audio;
        audio.currentTime = this.$refs.video.currentTime;
        audio.play().catch(() => {});
      }
      this.wakeControls();
    },
    onPause () {
      this.isPlaying = false;
      if (this.hasAudioTracks) this.$refs.audio.pause();
      this.showControls();
    },
    onTimeUpdate () {
      const video = this.$refs.video;
      this.currentTime = video.currentTime;
      if (this.nativeAudioDetected) this.detectNativeAudio();
      if (this.hasAudioTracks && !this.seeking) {
        const audio = this.$refs.audio;
        if (Math.abs(video.currentTime - audio.currentTime) > MAX_DRIFT) {
          audio.currentTime = video.currentTime;
        }
      }
    },
    onDurationChange () {
      const video = this.$refs.video;
      if (Number.isFinite(video.duration)) this.duration = video.duration;
      this.detectNativeAudio();
    },
    onProgress () {
      const video = this.$refs.video;
      if (video.buffered.length) this.buffered = video.buffered.end(video.buffered.length - 1);
      this.detectNativeAudio();
    },
    // No standard cross-browser way to ask "does this video have an audio channel" - each engine
    // exposes its own signal. audioTracks (Chrome/Edge) and mozHasAudio (Firefox) are known as
    // soon as metadata loads; Safari's webkitAudioDecodedByteCount only rises once audio has
    // actually decoded, so a silent video reads the same as an unplayed one until playback has
    // had a moment to run - hence the currentTime threshold before calling it silent there.
    detectNativeAudio () {
      const video = this.$refs.video;
      if (this.hasAudioTracks || !video) return;
      if (video.audioTracks) {
        this.nativeAudioDetected = video.audioTracks.length > 0;
      } else if (typeof video.mozHasAudio === "boolean") {
        this.nativeAudioDetected = video.mozHasAudio;
      } else if (typeof video.webkitAudioDecodedByteCount === "number") {
        if (video.webkitAudioDecodedByteCount > 0) this.nativeAudioDetected = true;
        else if (video.currentTime > 1) this.nativeAudioDetected = false;
      }
    },
    formatTime (seconds) {
      if (!Number.isFinite(seconds)) return "0:00";
      const total = Math.floor(seconds);
      const m = Math.floor(total / 60);
      const s = total % 60;
      return `${m}:${s.toString().padStart(2, "0")}`;
    },
    seekTo (clientX) {
      const rect = this.$refs.seek.getBoundingClientRect();
      const ratio = Math.min(1, Math.max(0, (clientX - rect.left) / rect.width));
      const video = this.$refs.video;
      const time = ratio * (this.duration || 0);
      video.currentTime = time;
      this.currentTime = time;
      if (this.hasAudioTracks) this.$refs.audio.currentTime = time;
    },
    startSeek (event) {
      this.seeking = true;
      this.seekTo(event.clientX);
    },
    onSeekMove (event) {
      if (!this.seeking) return;
      this.seekTo(event.clientX);
    },
    stopSeek () {
      this.seeking = false;
    },
    toggleMute () {
      this.muted = !this.muted;
    },
    toggleRepeat () {
      this.repeatEnabled = !this.repeatEnabled;
    },
    toggleFullscreen () {
      // Both reject when the browser refuses the request (e.g. no active user gesture) - that's
      // not actionable here, just avoid it surfacing as an unhandled rejection.
      const request = document.fullscreenElement ? document.exitFullscreen() : this.$refs.container.requestFullscreen();
      request.catch(() => {});
    },
    onFullscreenChange () {
      this.isFullscreen = document.fullscreenElement === this.$refs.container;
    },
    changeTrack () {
      if (!this.hasAudioTracks) return;
      const audio = this.$refs.audio;
      const video = this.$refs.video;
      const wasPlaying = !video.paused;
      audio.src = this.selectedTrack.url;
      // Without an explicit load(), swapping src mid-playback can leave the old track's decoded
      // audio still queued behind the new one instead of replacing it - they end up briefly (or
      // not so briefly) playing on top of each other.
      audio.load();
      audio.currentTime = video.currentTime;
      if (wasPlaying) audio.play().catch(() => {});
    },
    showControls () {
      this.controlsVisible = true;
      clearTimeout(this.hideControlsTimer);
    },
    wakeControls () {
      this.mouseOverPlayer = true;
      this.showControls();
      if (!this.isPlaying) return;
      this.hideControlsTimer = setTimeout(() => {
        if (this.controlsFocused) return;
        this.controlsVisible = false;
      }, 2500);
    },
    onMouseLeave () {
      this.mouseOverPlayer = false;
      if (this.controlsFocused) return;
      if (!this.isPlaying) return;
      this.controlsVisible = false;
      clearTimeout(this.hideControlsTimer);
    },
    onTrackSelectFocus () {
      this.controlsFocused = true;
      this.showControls();
    },
    onTrackSelectBlur () {
      this.controlsFocused = false;
      // The mouse may have already left the player while the dropdown was open (its popup
      // draws outside the player's box, so opening it never fires the player's own mouseleave) -
      // now that it's closed, apply whatever the auto-hide state should actually be.
      if (this.isPlaying && !this.mouseOverPlayer) this.controlsVisible = false;
    },
  },
};
</script>
