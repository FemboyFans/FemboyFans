<template>
  <div class="input">
    <label>
      <div>Audio file</div>
      <input type="file" ref="audio_file" accept="audio/*,video/*" @change="updateFile" :disabled="!!uploadURL" />
    </label>
    <span class="hint">Any audio (or video, to pull just its audio) file - it'll be converted to AAC automatically.</span>
  </div>

  <div class="input">
    <label>
      <span class="linkinput-or">OR</span>
      <input type="text" size="50" placeholder="Paste a direct audio/video URL" v-model="uploadURL" :disabled="!!uploadValue" />
    </label>
  </div>

  <div class="input">
    <label>
      <div>Label</div>
      <input type="text" maxlength="100" placeholder="English Dub, Instrumental, ..." v-model="label" />
    </label>
  </div>

  <div class="input">
    <label>
      <div>Reason</div>
      <input type="text" size="50" maxlength="150" placeholder="Why should this track be added?" v-model="reason" />
    </label>
  </div>

  <div class="background-red error_message" v-if="errorMessage !== undefined">
    {{ errorMessage }}
  </div>

  <button @click="submit" :disabled="submitting || (!uploadValue && !uploadURL)">
    {{ submitting ? "Uploading..." : "Upload" }}
  </button>
</template>

<script>
import SparkMD5 from "spark-md5";
import Uploader from "./uploader";

export default {
  data() {
    return {
      uploadValue: undefined,
      uploadURL: "",
      label: "",
      reason: "",
      errorMessage: undefined,
      submitting: false,
      maxFileSizePerRequest: Uploader.settings.max_file_size_per_request,
    };
  },
  methods: {
    updateFile() {
      this.uploadValue = this.$refs.audio_file.files[0];
    },
    afterSuccess(data) {
      this.submitting = false;
      Danbooru.notice("Audio track submitted for review.");
      location.assign(data.location);
    },
    afterError(data) {
      this.submitting = false;
      this.errorMessage = data.responseJSON?.reason || data.responseJSON?.message;
    },
    uploadFiles(id) {
      const perRequest = this.maxFileSizePerRequest;
      const file = this.uploadValue;
      const chunks = Math.ceil(file.size / perRequest);

      const uploadChunk = (index) => {
        const start = index * perRequest;
        const end = Math.min(start + perRequest, file.size);
        const blob = file.slice(start, end);
        const formData = new FormData();
        formData.append("audio_track_media_asset[data]", blob);
        formData.append("audio_track_media_asset[chunk_id]", index + 1);
        $.ajax({
          url: `/media_assets/audio_tracks/${id}/append.json`,
          type: "PUT",
          data: formData,
          processData: false,
          contentType: false,
          success: () => {
            if (index < chunks - 1) {
              uploadChunk(index + 1);
            } else {
              this.finalizeUpload(id);
            }
          },
          error: (data) => {
            this.cancelUpload(id);
            this.afterError(data);
          }
        });
      };
      uploadChunk(0);
    },
    finalizeUpload(id) {
      $.ajax({
        url: `/media_assets/audio_tracks/${id}/finalize.json`,
        type: "PUT",
        success: (data) => this.afterSuccess(data),
        error: (data) => {
          this.cancelUpload(id);
          this.afterError(data);
        }
      });
    },
    cancelUpload(id) {
      $.ajax({ url: `/media_assets/audio_tracks/${id}/cancel.json`, type: "PUT" });
    },
    md5HashFile(file) {
      return new Promise((resolve, reject) => {
        const chunkSize = 1024 * 1024 * 2;
        const chunkCount = Math.ceil(file.size / chunkSize);
        let currentChunk = 0;
        const spark = new SparkMD5.ArrayBuffer();
        const reader = new FileReader();

        reader.onload = (e) => {
          spark.append(e.target.result);
          currentChunk++;
          if (currentChunk < chunkCount) {
            loadNext();
          } else {
            resolve(spark.end());
          }
        };
        reader.onerror = reject;

        function loadNext() {
          const start = currentChunk * chunkSize;
          const end = Math.min(start + chunkSize, file.size);
          reader.readAsArrayBuffer(file.slice(start, end));
        }
        loadNext();
      });
    },
    async submit() {
      if (this.submitting) return;
      this.submitting = true;
      const formData = new FormData();
      let directUpload = false;
      if (this.uploadURL) {
        formData.append("audio_track[direct_url]", this.uploadURL);
        directUpload = true;
      } else {
        const md5 = await this.md5HashFile(this.uploadValue);
        formData.append("audio_track[checksum]", md5);
        if (this.uploadValue.size <= this.maxFileSizePerRequest) {
          formData.append("audio_track[file]", this.uploadValue);
          directUpload = true;
        }
      }
      formData.append("audio_track[label]", this.label);
      formData.append("audio_track[reason]", this.reason);

      const postId = new URLSearchParams(window.location.search).get("post_id");
      $.ajax(`/posts/audio_tracks.json?post_id=${postId}`, {
        method: "POST",
        data: formData,
        processData: false,
        contentType: false,
        success: (data) => {
          if (directUpload) {
            this.afterSuccess(data);
          } else {
            this.uploadFiles(data.media_asset_id);
          }
        },
        error: this.afterError.bind(this)
      });
    }
  }
};
</script>
