import { Controller } from "@hotwired/stimulus";
import { error } from "../packs/application";

export default class extends Controller {
  static targets = ["frame"];

  connect () {
    this.originalSrc = this.frameTarget.src;
    this.originalHTML = this.frameTarget.innerHTML;
  }

  /**
   * Fires for every fetch response a turbo-frame makes, before Turbo tries to interpret it as
   * HTML/a frame - this is the only event that reliably sees error responses regardless of
   * content type. turbo:frame-missing only fires for HTML lacking a matching frame; a JSON (or
   * other non-HTML) error body never reaches that code path at all.
   * @param {CustomEvent} event
   */
  async handleBeforeFetchResponse (event) {
    /** @type {import("@hotwired/turbo").FetchResponse} */
    const fetchResponse = event.detail.fetchResponse;
    if (fetchResponse.succeeded) return;

    event.preventDefault();

    let message = `Something went wrong (${fetchResponse.statusCode}).`;
    if (fetchResponse.contentType?.includes("application/json")) {
      const data = await fetchResponse.response.json().catch(() => null);
      message = data?.message || data?.reason || message;
    } else {
      const html = await fetchResponse.responseHTML;
      console.error(`turbo-frame ${this.frameTarget.id} request failed (${fetchResponse.statusCode})`, html);
    }

    error(message);
    this.frameTarget.innerHTML = this.originalHTML;
  }
}
