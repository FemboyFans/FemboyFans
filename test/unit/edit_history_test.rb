# frozen_string_literal: true

require("test_helper")

class EditHistoryTest < ActiveSupport::TestCase
  context("EditHistory") do
    context("#text_content") do
      should("escape merged topic titles") do
        edit = build(
          :edit_history,
          edit_type:  "merge",
          extra_data: {
            old_topic_id:    123,
            old_topic_title: %(<script>alert("old")</script>),
            new_topic_id:    456,
            new_topic_title: %(<img src=x onerror=alert("new")>),
          },
        )

        html = edit.text_content

        assert_includes(html, %(href="#{Routes.forum_topic_path(456)}"))
        assert_includes(html, "&lt;img src=x onerror=alert(&quot;new&quot;)&gt;")
        assert_includes(html, "&lt;script&gt;alert(&quot;old&quot;)&lt;/script&gt;")
        assert_not_includes(html, "<img")
        assert_not_includes(html, "<script>")
      end
    end
  end
end
