# frozen_string_literal: true

require("test_helper")

class ApplicationJobTest < ActiveSupport::TestCase
  context("ApplicationJob") do
    should("discard jobs whose record argument no longer exists instead of retrying") do
      asset = create(:upload_media_asset)
      MediaAssetDeleteTempfileJob.perform_later(asset)
      asset.destroy

      assert_nothing_raised { perform_enqueued_jobs }
      assert_empty(enqueued_jobs)
    end
  end
end
