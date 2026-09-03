# frozen_string_literal: true

class AudioTrackPolicy < ApplicationPolicy
  def create?
    member? && user.can_replace?
  end

  def approve?
    approver?
  end

  def reject?
    approver?
  end

  def set_default?
    approver?
  end

  def destroy?
    user.is_admin?
  end

  def permitted_attributes
    %i[direct_url file reason label]
  end

  def permitted_search_params
    params = super + %i[label status creator_id creator_name approver_id approver_name rejector_id rejector_name post_id is_default file_md5] + nested_search_params(creator: User, approver: User, rejector: User)
    params << :ip_addr if can_search_ip_addr?
    params
  end

  def api_attributes
    super + %i[apionly_file_url creator_name media_asset_id] - %i[audio_track_media_asset_id]
  end

  def visible_for_search(relation)
    q = super
    return q.approved if user.is_anonymous?
    return q if user.is_staff?
    q.for_creator(user).or(q.approved)
  end
end
