# frozen_string_literal: true

module Admin
  module ApplicationLogsHelper
    ANSI_ESCAPE = "\e["
    ANSI_COLORS = {
      30 => "#7f848e",
      31 => "#ff6b6b",
      32 => "#7bd88f",
      33 => "#ffd866",
      34 => "#6aa9ff",
      35 => "#d38cff",
      36 => "#66d9ef",
      37 => "#f8f8f2",
      90 => "#7f848e",
      91 => "#ff6b6b",
      92 => "#7bd88f",
      93 => "#ffd866",
      94 => "#6aa9ff",
      95 => "#d38cff",
      96 => "#66d9ef",
      97 => "#ffffff",
    }.freeze

    def format_application_log_line(text)
      normalized = text.to_s.gsub("␛[", ANSI_ESCAPE)
      state = default_ansi_state
      parts = []
      pos = 0

      while (match = normalized.match(/\e\[([0-9;]*)m/, pos))
        parts << render_ansi_segment(normalized[pos...match.begin(0)], state)
        apply_ansi_codes(state, match[1])
        pos = match.end(0)
      end

      parts << render_ansi_segment(normalized[pos..], state)
      safe_join(parts.compact)
    end

    private

    def default_ansi_state
      { bold: false, color: nil }
    end

    def apply_ansi_codes(state, codes)
      values = codes.to_s.split(";").compact_blank.map(&:to_i)
      values = [0] if values.empty?

      values.each do |code|
        case code
        when 0
          state.replace(default_ansi_state)
        when 1
          state[:bold] = true
        when 22
          state[:bold] = false
        when 39
          state[:color] = nil
        else
          state[:color] = ANSI_COLORS[code] if ANSI_COLORS.key?(code)
        end
      end
    end

    def render_ansi_segment(text, state)
      return if text.blank?
      return text unless state[:bold] || state[:color].present?

      styles = []
      styles << "font-weight: bold" if state[:bold]
      styles << "color: #{state[:color]}" if state[:color].present?
      tag.span(text, style: styles.join("; "))
    end
  end
end
