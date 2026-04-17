<template>
  <file-input @previewChanged="previewData = $event"
    @uploadValueChanged="uploadValue = $event"></file-input>
  <br>

  <div class="input">
    <label>
      Additional Source
      <sources :maxSources="1" :showErrors="showErrors" @sourceWarning="sourceWarning = $event" v-model:sources="sources"></sources>
    </label>
    <span class="hint">The submission page the replacement file came from</span>
  </div>

  <div class="input">
    <label>
      <div>Reason</div>
      <autocompletable-input listId="reason-datalist" :addToList="submittedReason" size="50" placeholder="Higher quality, artwork updated, official uncensored version, ..." v-model="reason"></autocompletable-input>
    </label>
    <span class="hint">Tell us why this file should replace the original.</span>
  </div>

  <div v-if="allowUploadAsPending" class="input">
    <label><input type="checkbox" v-model="uploadAsPending"/> Upload as Pending</label>
    <span class="hint">If you aren't sure if this replacement is correct, checking this box will put it into the moderation queue.</span>
  </div>

  <div class="background-red error_message" v-if="showErrors && errorMessage !== undefined">
    {{ errorMessage }}
  </div>

  <button @click="submit" :disabled="(showErrors && preventUpload) || submitting">
      {{ submitting ? "Uploading..." : "Upload" }}
  </button>

  <file-preview :data="previewData"></file-preview>
</template>

<script>
import autocompletableInput from "./autocompletable_input.vue";
import filePreview from "./uploader/file_preview.vue";
import fileInput from "./uploader/file_input.vue";
import sources from "./uploader/sources.vue";
import Utility from "./utility";
import SparkMD5 from "spark-md5";
import Uploader from "./uploader";
import CurrentUser from "./models/CurrentUser";

export default {
  components: {
    "autocompletable-input": autocompletableInput,
    "file-preview": filePreview,
    "file-input": fileInput,
    "sources": sources,
  },
  data() {
    return {
      previewData: {
        url: "",
        isVideo: false,
      },
      sources: [""],
      uploadValue: "",
      reason: "",
      allowUploadAsPending: Uploader.settings.allow_upload_as_pending,
      uploadAsPending: false,
      errorMessage: undefined,
      showErrors: false,
      sourceWarning: false,
      submitting: false,
      submittedReason: undefined,
      canApprove: CurrentUser.canApprovePosts,
      maxFileSizePerRequest: Uploader.settings.max_file_size_per_request,
    };
  },
  mounted() {
    const params = new URLSearchParams(window.location.search);
    if (params.has("additional_source"))
      this.sources = [params.get("additional_source")];

    if (params.has("reason"))
      this.reason = params.get("reason");
  },
  computed: {
    preventUpload() {
      return this.sourceWarning;
    }
  },
  methods: {
    afterSuccess(data) {
      this.submitting = false;
      this.allowNavigate = true;
      Danbooru.notice("Replacement uploaded successfully.");
      location.assign(data.location);
    },
    afterError(data) {
      this.submitting = false;
      this.errorMessage = data.responseJSON.reason || data.responseJSON.message;
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
        formData.append("post_replacement_media_asset[data]", blob);
        formData.append("post_replacement_media_asset[chunk_id]", index + 1);
        $.ajax({
          url: `/media_assets/post_replacements/${id}/append.json`,
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
      }
      uploadChunk(0);
    },
    finalizeUpload(id) {
      $.ajax({
        url: `/media_assets/post_replacements/${id}/finalize.json`,
        type: "PUT",
        success: (data) => {
          this.afterSuccess(data);
        },
        error: (data) => {
          this.cancelUpload(id);
          this.afterError(data);
        }
      });
    },
    cancelUpload(id) {
      $.ajax({
        url: `/media_assets/post_replacements/${id}/cancel.json`,
        type: "PUT"
      });
    },
    md5HashFile(file) {
      return new Promise((resolve, reject) => {
        const chunkSize = 1024 * 1024 * 2;
        const chunkCount = Math.ceil(file.size / chunkSize);
        let currentChunk = 0, hash = null;
        const spark = new SparkMD5.ArrayBuffer();
        const reader = new FileReader();

        reader.onload = function (e) {
          spark.append(e.target.result);
          currentChunk++;

          if (currentChunk < chunkCount) {
            loadNext();
          } else {
            resolve(spark.end());
          }
        }

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
      this.showErrors = true;
      if(this.preventUpload || this.submitting) {
        return;
      }
      this.submitting = true;
      const formData = new FormData();
      let directUpload = false;
      if (typeof this.uploadValue === "string") {
        formData.append("post_replacement[direct_url]", this.uploadValue);
        directUpload = true
      } else {
        const md5 = await this.md5HashFile(this.uploadValue);
        formData.append("post_replacement[checksum]", md5);
        const small = this.uploadValue.size <= this.maxFileSizePerRequest;
        if (small) {
          formData.append("post_replacement[file]", this.uploadValue);
          directUpload = true
        }
      }
      formData.append("post_replacement[source]", this.sources[0]);
      formData.append("post_replacement[reason]", this.reason);
      if (this.allowUploadAsPending) {
        formData.append("post_replacement[as_pending]", this.uploadAsPending);
      }

      this.submittedReason = this.reason;

      const postId = new URLSearchParams(window.location.search).get("post_id");
      $.ajax(`/posts/replacements.json?post_id=${postId}`, {
        method: "POST",
        data: formData,
        processData: false,
        contentType: false,
        success: (data) => {
          if (directUpload) {
            this.afterSuccess(data);
          } else {
            this.uploadFiles(data.media_asset_id)
          }
        },
        error: this.afterError.bind(this)
      });
    }
  }
};
</script>
