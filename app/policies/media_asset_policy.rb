# frozen_string_literal: true

class MediaAssetPolicy < ApplicationPolicy
  def index?
    member?
  end

  def append?
    member? && creator?
  end

  def finalize?
    member? && creator?
  end

  def cancel?
    member? && creator?
  end

  def show_statuses?
    user.is_admin?
  end

  def queue_statuses?
    user.is_admin?
  end

  def creator?
    !record.is_a?(MediaAsset) || record.creator_id == user.id
  end

  def permitted_search_params
    params = super + %I[checksum md5 file_ext pixel_hash status status_message_matches creator_id creator_name #{model.model.name.underscore}_id] + nested_search_params(creator: User, "#{model.model.name.underscore}": model.model)
    params << :ip_addr if can_search_ip_addr?
    params
  end

  def api_attributes
    super - %i[media_metadata_id checksum last_chunk_id]
  end

  def visible_for_search(relation)
    q = super
    return q if user.is_staff?
    q.for_creator(user)
  end

  def model
    self.class.name.delete_suffix("Policy").constantize
  end
end
