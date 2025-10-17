# frozen_string_literal: true

class DmailPolicy < ApplicationPolicy
  def index?
    unbanned?
  end

  def create?
    unbanned?
  end

  def show?
    unbanned? && (!record.is_a?(Dmail) || record.visible_to?(user))
  end

  def respond?
    unbanned? && (!record.is_a?(Dmail) || (record.visible_to?(user) && record.owner_id == user.id))
  end

  def destroy?
    unbanned? && (!record.is_a?(Dmail) || record.owner_id == user.id)
  end

  def mark_spam?
    user.is_moderator? && (!record.is_a?(Dmail) || record.visible_to?(user))
  end

  def mark_not_spam?
    user.is_moderator? && (!record.is_a?(Dmail) || record.visible_to?(user))
  end

  def mark_as_read?
    unbanned? && (!record.is_a?(Dmail) || record.owner_id == user.id)
  end

  def mark_as_unread?
    unbanned? && (!record.is_a?(Dmail) || record.owner_id == user.id)
  end

  def mark_all_as_read?
    unbanned?
  end

  def permitted_attributes
    %i[title body to_name to_id]
  end

  def permitted_search_params
    (super - %i[order]) + %i[title_matches message_matches to_name to_id from_name from_id is_read is_deleted read owner_id owner_name] + nested_search_params(to: User, from: User, owner: User)
  end

  def api_attributes
    super - %i[key] + %i[owner_name to_name from_name]
  end

  def html_data_attributes
    attr = super
    attr += %i[apionly_is_owner?] if user.is_owner?
    attr
  end

  def visible_for_search(relation)
    q = super
    return q if user.is_owner?
    q.owned_by(user)
  end
end
