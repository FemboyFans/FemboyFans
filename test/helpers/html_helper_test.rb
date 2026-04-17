# frozen_string_literal: true

require("test_helper")

class HtmlHelperTest < ActionView::TestCase
  context("HtmlHelper") do
    context("#vote_display") do
      should("strip dangerous html while preserving allowed markup") do
        vote = stub(vote_display: %(<span class="text-yellow" onclick="alert(1)">Locked</span> <script>alert(1)</script>))

        html = vote_display(vote)

        assert_includes(html, %(<span class="text-yellow">Locked</span>))
        assert_not_includes(html, "onclick=")
        assert_not_includes(html, "<script>")
      end
    end
  end
end
