# frozen_string_literal: true

require("test_helper")

class IqdbUpdateJobTest < ActiveSupport::TestCase
  context("IqdbUpdateJob") do
    should("retry instead of raising when iqdb update fails") do
      post = create(:post)
      IqdbProxy.stubs(:update_post).raises(IqdbProxy::Error, "failed to generate thumb")

      assert_nothing_raised do
        IqdbUpdateJob.perform_later(post.id)
        perform_enqueued_jobs
      end

      assert_enqueued_with(job: IqdbUpdateJob, args: [post.id])
    end

    should("do nothing if the post no longer exists") do
      IqdbProxy.expects(:update_post).never

      assert_nothing_raised { IqdbUpdateJob.perform_now(-1) }
    end
  end
end
