# frozen_string_literal: true

class PostSetVersion < ApplicationRecord
  belongs_to_user(:updater, ip: true, counter_cache: "set_update_count")
  undoable
  belongs_to(:post_set)
  before_validation(:fill_version, on: :create)
  before_validation(:fill_changes, on: :create)

  def self.calculate_version(post_set_id)
    1 + where(post_set_id: post_set_id).maximum(:version).to_i
  end

  def self.queue(post_set, updater)
    create({
      post_set_id:        post_set.id,
      post_ids:           post_set.post_ids,
      updater_id:         updater.id,
      updater_ip_addr:    updater.ip_addr,
      name:               post_set.name,
      shortname:          post_set.shortname,
      description:        post_set.description,
      is_public:          post_set.is_public,
      transfer_on_delete: post_set.transfer_on_delete,
      maintainer_ids:     post_set.approved_maintainers.pluck(:id),
    })
  end

  def previous
    @previous ||= PostSetVersion.where(post_set_id: post_set_id).where.lt(version: version).order(version: :desc).first
  end

  def pretty_name
    name&.tr("_", " ") || "(Unknown Name)"
  end

  module ChangeMethods
    def fill_version
      self.version = PostSetVersion.calculate_version(post_set_id)
    end

    def fill_changes
      if previous
        self.added_post_ids = post_ids - previous.post_ids
        self.removed_post_ids = previous.post_ids - post_ids
        self.added_maintainer_ids = maintainer_ids - previous.maintainer_ids
        self.removed_maintainer_ids = previous.maintainer_ids - maintainer_ids
      else
        self.added_post_ids = post_ids
        self.removed_post_ids = []
        self.added_maintainer_ids = maintainer_ids
        self.removed_maintainer_ids = []
      end

      self.name_changed = previous.nil? || name != previous.name
      self.shortname_changed = previous.nil? || shortname != previous.shortname
      self.description_changed = previous.nil? || description != previous.description
      self.is_public_changed = previous.nil? || is_public != previous.is_public
      self.transfer_on_delete_changed = previous.nil? || transfer_on_delete != previous.transfer_on_delete
    end

    def changes_text
      return %w[created] if version == 1
      list = []
      if added_post_ids.any? || removed_post_ids.any?
        text = "posts ("
        text += "+#{added_post_ids.size}, " if added_post_ids.any?
        text += "-#{removed_post_ids.size}" if removed_post_ids.any?
        list << "#{text.delete_suffix(', ')})"
      end
      if added_maintainer_ids.any? || removed_maintainer_ids.any?
        text = "maintainers ("
        text += "+#{added_maintainer_ids.size}, " if added_maintainer_ids.any?
        text += "-#{removed_maintainer_ids.size}" if removed_maintainer_ids.any?
        list << "#{text.delete_suffix(', ')})"
      end
      list << "name" if name_changed?
      list << "shortname" if shortname_changed?
      list << "description" if description_changed?
      list << "made public" if is_public_changed? && is_public?
      list << "made private" if is_public_changed? && !is_public?
      list << "transfer on delete enabled" if transfer_on_delete_changed? && transfer_on_delete?
      list << "transfer on delete disabled" if transfer_on_delete_changed? && !transfer_on_delete?
      list
    end
  end

  module SearchMethods
    def default_order
      order(id: :desc)
    end

    def query_dsl
      super
        .field(:post_set_id)
        .field(:name_matches, :name)
        .field(:description_matches, :description)
        .field(:ip_addr, :updater_ip_addr)
        .association(:updater)
        .association(:post_set)
    end
  end

  include(ChangeMethods)
  extend(SearchMethods)

  def self.available_includes
    %i[post_set updater]
  end
end
