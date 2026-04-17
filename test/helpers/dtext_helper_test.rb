# frozen_string_literal: true

require("test_helper")

class DtextHelperTest < ActiveSupport::TestCase
  context("DTextHelper") do
    context(".parse") do
      should("escape raw html input") do
        html = DTextHelper.parse(%(<script>alert("xss")</script><img src=x onerror=alert("xss")>)).fetch(:dtext)

        assert_includes(html, '&lt;script&gt;alert("xss")&lt;/script&gt;')
        assert_includes(html, '&lt;img src=x onerror=alert("xss")&gt;')
        assert_not_includes(html, "<script>alert(\"xss\")</script>")
        assert_not_includes(html, %{<img src=x onerror=alert("xss")>})
      end
    end
  end
end
