# frozen_string_literal: true

module WikiPagesHelper
  def link_to_wiki_or_new(text, tag = text, **)
    link_to(text, show_or_new_wiki_pages_path(title: tag), **)
  end

  def multiple_link_to_wiki_or_new(tags)
    safe_join(tags.map { |tag| link_to_wiki_or_new(tag) }, ", ")
  end

  def wiki_page_alias_and_implication_list(wiki_page)
    render("tags/alias_and_implication_list", tag: wiki_page.tag || Tag.new(name: wiki_page.title))
  end

  def wiki_page_post_previews(wiki_page)
    tag.div(id: "wiki-page-posts") do
      if Post.system_count(wiki_page.title) > 0
        header = tag.h2(safe_join(["Posts (", link_to("view all", posts_path(tags: wiki_page.title)), ")"]))
        header + wiki_page.post_set(CurrentUser.user).presenter.post_previews_html(self)
      end
    end
  end

  delegate(:safe_wiki, to: :WikiPage)
end
