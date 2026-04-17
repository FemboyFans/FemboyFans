# frozen_string_literal: true

module PostSetPresenters
  module Popular
    class Uploads < Base
      attr_accessor(:post_set, :tag_set_presenter)

      delegate(:posts, :date, :min_date, :max_date, to: :post_set)

      def initialize(post_set, helper: nil, view: nil)
        super(helper, view)
        @post_set = post_set
      end

      def prev_day
        date - 1.day
      end

      def next_day
        date + 1.day
      end

      def prev_week
        date - 7.days
      end

      def next_week
        date + 7.days
      end

      def prev_month
        1.month.ago(date)
      end

      def next_month
        1.month.since(date)
      end

      def link_rel_for_scale?(template, scale)
        (template.params[:scale].blank? && scale == "day") || template.params[:scale].to_s.include?(scale)
      end

      def next_date_for_scale(scale)
        case scale
        when "Day"
          next_day
        when "Week"
          next_week
        when "Month"
          next_month
        end
      end

      def prev_date_for_scale(scale)
        case scale
        when "Day"
          prev_day
        when "Week"
          prev_week
        when "Month"
          prev_month
        end
      end

      def nav_links_for_scale(template, scale)
        parts = []
        parts << link_to("«prev", r.uploads_popular_index_path(date: prev_date_for_scale(scale).strftime("%Y-%m-%d"), scale: scale.downcase),
                         id:   link_rel_for_scale?(template, scale.downcase) ? "paginator-prev" : nil,
                         rel:  link_rel_for_scale?(template, scale.downcase) ? "prev" : nil,
                         data: { shortcut: link_rel_for_scale?(template, scale.downcase) ? "a left" : nil })
        parts << link_to(scale, r.uploads_popular_index_path(date: date.strftime("%Y-%m-%d"), scale: scale.downcase), class: "desc")
        parts << link_to("next»", r.uploads_popular_index_path(date: next_date_for_scale(scale).strftime("%Y-%m-%d"), scale: scale.downcase),
                         id:   link_rel_for_scale?(template, scale.downcase) ? "paginator-next" : nil,
                         rel:  link_rel_for_scale?(template, scale.downcase) ? "next" : nil,
                         data: { shortcut: link_rel_for_scale?(template, scale.downcase) ? "d right" : nil })
        h.tag.span(safe_join(parts), class: "period")
      end

      def nav_links(template)
        parts =  []
        parts << nav_links_for_scale(template, "Day")
        parts << nav_links_for_scale(template, "Week")
        parts << nav_links_for_scale(template, "Month")
        h.tag.p(safe_join(parts), id: "popular-nav-links")
      end

      def range_text
        if min_date == max_date
          date.strftime("%B %d, %Y")
        elsif max_date - min_date < 10.days
          min_date.strftime("Week of %B %d, %Y")
        else
          date.strftime("%B %Y")
        end
      end
    end
  end
end
