# frozen_string_literal: true

module PostSetPresenters
  class Base < ::ApplicationPresenter
    def posts
      raise(NotImplementedError)
    end

    def post_previews_html(template, options = {})
      if posts.empty?
        return template.render("posts/blank")
      end

      options.merge!(tags: @post_set.public_tag_string)
      views_list = options.delete(:views_list) || {}
      unique_views = options.key?(:unique_views) ? options.delete(:unique_views) : CurrentUser.user.unique_views?
      previews = posts.map do |post|
        o = options.dup
        if views_list.key?(post.id)
          o[:views] = [o[:views], unique_views, views_list[post.id]] # XXX: this is ugly, and can cause unexpected behavior when assuming the key can only be a symbol
        end
        PostPresenter.preview(post, o)
      end
      template.safe_join(previews)
    end
  end
end
