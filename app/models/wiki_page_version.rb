# frozen_string_literal: true

class WikiPageVersion < ApplicationRecord
  belongs_to(:wiki_page)
  belongs_to_user(:updater, ip: true, counter_cache: "wiki_update_count")
  belongs_to(:artist, optional: true)
  delegate(:visible?, to: :wiki_page)

  module SearchMethods
    def for_user(user_id)
      where("updater_id = ?", user_id)
    end

    def search(params, user)
      q = super

      q = q.where_user(:updater_id, :updater, params)

      if params[:wiki_page_id].present?
        q = q.where("wiki_page_id = ?", params[:wiki_page_id].to_i)
      end

      q = q.attribute_matches(:title, params[:title])
      q = q.attribute_matches(:body, params[:body])
      q = q.attribute_matches(:is_locked, params[:is_locked])

      if params[:ip_addr].present?
        q = q.where("updater_ip_addr <<= ?", params[:ip_addr])
      end

      q.apply_basic_order(params)
    end
  end

  extend(SearchMethods)

  def pretty_title
    title.tr("_", " ")
  end

  def previous
    return @previous if defined?(@previous)
    @previous = WikiPageVersion.where("wiki_page_id = ? and id < ?", wiki_page_id, id).order("id desc").first
  end

  def category_id
    Tag.category_for(title)
  end

  def self.available_includes
    %i[artist updater wiki_page]
  end
end
