import VueAudioTrackUploader from "./audio_track_uploader.vue";
import { createApp } from "vue";
import Page from "./utility/page";
import Uploader from "./uploader";

class AudioTracker {
  static init () {
    const app = createApp(VueAudioTrackUploader);
    app.mount("#audio-track-uploader");
  }
}

export default AudioTracker;

$(async function () {
  if (Page.matches("posts-audio-tracks", "new")) {
    await Uploader.loadSettings();
    AudioTracker.init();
  }
});
