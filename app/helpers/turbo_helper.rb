# frozen_string_literal: true

module TurboHelper
  # turbo:before-fetch-response fires for every fetch response a frame makes - any status, any
  # content-type - before Turbo tries to interpret it as anything. That makes it the only event
  # that reliably sees error responses regardless of shape: turbo:frame-missing only fires for
  # HTML without a matching frame, and turbo:fetch-request-error only fires for network-level
  # failures - neither catches a JSON (or other non-HTML) error body.
  def turbo_frame(id, *, data: {}, **, &)
    tag.div(data: { controller: "turbo" }) do
      turbo_frame_tag(id, *, data: data.merge({ "turbo-target": "frame", "action": "turbo:before-fetch-response->turbo#handleBeforeFetchResponse" }), **, &)
    end
  end
end
