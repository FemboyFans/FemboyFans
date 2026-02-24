import Utility from "./utility";
import Page from "./utility/page";
import {SendQueue} from "./send_queue";

export default class FileStatuses {
  static initialize () {
    const queueButton = $("a#queue");
    queueButton.on("click", e => {
      e.preventDefault();
      const mainText = $(".main-text");
      mainText.text("Queuing...");
      SendQueue.add(() => {
        $.ajax("/media_assets/status.json", {
          method: "PUT",
        }).done(() => {
          mainText.text("Loading...");
          this.check_and_update_loading();
        }).fail((data) => {
          Utility.error(`Failed to queue: ${JSON.stringify(data)}`);
        });
      });
    });
    const url = new URL(window.location.href);
    if (url.searchParams.get("refresh") === "true") {
      url.searchParams.delete("refresh");
      window.history.replaceState({}, "", url.toString());
      queueButton.click();
    }
  }

  static check_and_update_loading () {
    const mainText = $(".main-text");
    const start = Date.now();
    let done = false, interval;
    const check = () => {
      SendQueue.add(() => {
        $.ajax("/media_assets/status.json")
          .done((data) => {
            if (data.cached) {
              done = true;
              if (interval) clearInterval(interval);
              mainText.text("Finished loading, refreshing page..");
              setTimeout(() => window.location.reload(), 1000);
            } else {
              const now = Date.now();
              const seconds = Math.floor((now - start) / 1000);
              mainText.text(`Loading... ${seconds} seconds`);
            }
          })
          .fail((data) => {
            Utility.error(`Failed to load: ${JSON.stringify(data)}`);
            if (interval) clearInterval(interval);
          });
      });
    };
    check();
    if (!done) interval = setInterval(check, 5000);
  }
}


$(function () {
  if (Page.matches("media-assets-statuses", "show")) FileStatuses.initialize();
});
