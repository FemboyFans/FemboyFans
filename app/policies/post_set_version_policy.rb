# frozen_string_literal: true

class PostSetVersionPolicy < ApplicationPolicy
  # Unlike pools (always public), a set's version history follows the set's own visibility -
  # private sets keep their history private to the owner/moderators too.
  def show?
    view_access?
  end

  def diff?
    view_access?
  end

  def undo?
    edit_access?
  end

  def permitted_search_params
    params = super + %i[updater_id updater_name name_matches description_matches post_set_id] + nested_search_params(updater: User, post_set: PostSet)
    params += %i[ip_addr] if can_search_ip_addr?
    params
  end

  def visible_for_search(relation)
    relation.where(post_set_id: PostSet.visible(user).select(:id))
  end

  private

  def view_access?
    return true unless record.is_a?(PostSetVersion)
    record.post_set.can_view?(user)
  end

  def edit_access?
    return unbanned? unless record.is_a?(PostSetVersion)
    unbanned? && record.post_set.can_edit_settings?(user)
  end
end
