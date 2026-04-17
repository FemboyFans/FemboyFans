import VueReplacer from "./replacement_uploader.vue";
import { createApp } from "vue";
import Page from "./utility/page";
import Uploader from "./uploader";

class Replacer {
  static init () {
    const app = createApp(VueReplacer);
    app.mount("#replacement-uploader");
  }
}

export default Replacer;

$(async function() {
  if (Page.matches("posts-replacements", "new")) {
    await Uploader.loadSettings();
    Replacer.init();
  }
});
