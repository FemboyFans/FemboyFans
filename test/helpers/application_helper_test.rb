# frozen_string_literal: true

require("test_helper")

class ApplicationHelperTest < ActionView::TestCase
  context("The application helper") do
    context("format_text method") do
      should("not raise an exception for invalid DText") do
        dtext = "a\x00b"

        assert_nothing_raised { format_text(dtext) }
        assert_equal('<div class="styled-dtext"></div>', format_text(dtext))
      end

      should("not emit script tags for raw html input") do
        html = format_text(%(<script>alert("xss")</script><img src=x onerror=alert("xss")>))

        assert_includes(html, '&lt;script&gt;alert("xss")&lt;/script&gt;')
        assert_includes(html, '&lt;img src=x onerror=alert("xss")&gt;')
        assert_not_includes(html, "<script>")
        assert_not_includes(html, "<script>alert(\"xss\")</script>")
        assert_not_includes(html, %{<img src=x onerror=alert("xss")>})
      end

      should("return empty output when dtext parsing raises") do
        DTextHelper.stubs(:parse).raises(DText::Error)

        assert_equal(%(<div class="styled-dtext"></div>), format_text("bad input"))
      end
    end
  end
end
