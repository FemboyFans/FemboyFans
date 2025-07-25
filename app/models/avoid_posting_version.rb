# frozen_string_literal: true

class AvoidPostingVersion < ApplicationRecord
  belongs_to_user(:updater, ip: true)
  belongs_to(:avoid_posting)
  has_one(:artist, through: :avoid_posting)
  delegate(:artist_id, :artist_name, to: :avoid_posting)

  def status
    if is_active?
      "Active"
    else
      "Deleted"
    end
  end

  def previous
    AvoidPostingVersion.joins(:avoid_posting).where(avoid_posting_versions: { id: ...id }).order(id: :desc).first
  end

  module SearchMethods
    def artist_search(params, user)
      Artist.search(user, params.slice(:any_name_matches, :any_other_name_matches).merge({ id: params[:artist_id], name: params[:artist_name] }))
    end

    def search(params, user)
      q = super
      artist_keys = %i[artist_id artist_name any_name_matches any_other_name_matches]
      q = q.joins(:artist).merge(artist_search(params, user)) if artist_keys.any? { |key| params.key?(key) }

      q = q.attribute_matches(:is_active, params[:is_active])
      q = q.where_user(:updater_id, :updater, params)
      q = q.where("updater_ip_addr <<= ?", params[:ip_addr]) if params[:ip_addr].present?
      q.apply_basic_order(params)
    end
  end

  extend(SearchMethods)

  def self.available_includes
    %i[artist updater avoid_posting]
  end
end
