# frozen_string_literal: true

module ArtistVersionsHelper
  def artist_versions_listing_type
    params.dig(:search, :artist_id).present? && CurrentUser.user.is_member? ? :revert : :standard
  end

  def artist_version_other_names_diff(artist_version)
    new_names = artist_version.other_names
    old_names = artist_version.previous.try(:other_names)
    if artist_version.artist.present?
      latest_names = artist_version.artist.other_names
    else
      latest_names = new_names
    end

    diff_list_html(new_names, old_names, latest_names)
  end

  def artist_version_urls_diff(artist_version)
    new_urls = artist_version.urls
    old_urls = artist_version.previous.try(:urls)
    if artist_version.artist.present?
      latest_urls = artist_version.artist.urls.map(&:to_s)
    else
      latest_urls = new_urls
    end

    diff_list_html(new_urls, old_urls, latest_urls)
  end
end
