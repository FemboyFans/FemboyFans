# frozen_string_literal: true

require("test_helper")

module Admin
  class ApplicationLogsHelperTest < ActionView::TestCase
    context("ApplicationLogsHelper") do
      should("format real ansi escape codes") do
        html = format_application_log_line("\e[1m\e[31merror\e[0m")

        assert_includes(html, "error")
        assert_includes(html, "font-weight: bold; color: #ff6b6b")
        assert_not_includes(html, "\e[31m")
      end

      should("format visible ansi escape markers") do
        html = format_application_log_line("␛[36minfo␛[0m")

        assert_includes(html, "info")
        assert_includes(html, "color: #66d9ef")
        assert_not_includes(html, "␛[36m")
      end

      should("escape html inside ansi formatted output") do
        html = format_application_log_line("␛[33m<script>alert(1)</script>␛[0m")

        assert_includes(html, "&lt;script&gt;alert(1)&lt;/script&gt;")
        assert_not_includes(html, "<script>")
      end
    end
  end
end
