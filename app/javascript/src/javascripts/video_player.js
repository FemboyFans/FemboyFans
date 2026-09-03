import { createApp } from "vue";
import VideoPlayer from "./video_player.vue";

class VideoPlayerLoader {
  static init (mount) {
    const props = {
      sources: JSON.parse(mount.dataset.sources || "[]"),
      poster: mount.dataset.poster || null,
      videoClass: mount.dataset.videoClass || "",
      audioTracks: JSON.parse(mount.dataset.audioTracks || "[]"),
    };
    createApp(VideoPlayer, props).mount(mount);
  }
}

export default VideoPlayerLoader;

$(function () {
  const mount = document.getElementById("video-player");
  if (!mount) return;
  VideoPlayerLoader.init(mount);
});
