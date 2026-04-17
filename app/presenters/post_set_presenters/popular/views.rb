# frozen_string_literal: true

module PostSetPresenters
  module Popular
    class Views < Base
      attr_accessor(:post_set, :tag_set_presenter)

      delegate(:posts, :date, to: :post_set)

      def initialize(post_set, helper: nil, view: nil)
        super(helper, view)
        @post_set = post_set
      end

      def next_date
        date + 1.day
      end

      def prev_date
        date - 1.day
      end

      def nav_links
        parts = []
        links = []
        links << link_to("«prev", r.views_popular_index_path(date: prev_date.strftime("%Y-%m-%d")), id: "paginator-prev", rel: "prev", data: { shortcut: "a left" })
        links << link_to("Day", r.views_popular_index_path(date: date.strftime("%Y-%m-%d")), class: "desc")
        links << link_to("next»", r.views_popular_index_path(date: next_date.strftime("%Y-%m-%d")), id: "paginator-next", rel: "next", data: { shortcut: "d right" })
        parts << h.tag.span(safe_join(links), class: "period")
        parts << h.tag.span(link_to("All Time", r.top_views_popular_index_path), class: "period")
        h.tag.p(safe_join(parts), id: "popular-nav-links")
      end

      def range_text
        date.strftime("%B %Y")
      end
    end
  end
end
