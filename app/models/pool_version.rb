# frozen_string_literal: true

class PoolVersion < ApplicationRecord
  belongs_to_user(:updater, ip: true, counter_cache: "pool_update_count")
  belongs_to(:pool)
  before_validation(:fill_version, on: :create)
  before_validation(:fill_changes, on: :create)

  module SearchMethods
    def default_order
      order(updated_at: :desc)
    end

    def for_user(user_id)
      where("updater_id = ?", user_id)
    end

    def search(params, user)
      q = super

      q = q.where_user(:updater_id, :updater, params)

      if params[:pool_id].present?
        q = q.where(pool_id: params[:pool_id].split(",").map(&:to_i))
      end

      if params[:ip_addr].present?
        q = q.where("updater_ip_addr <<= ?", params[:ip_addr])
      end

      q.apply_basic_order(params)
    end
  end

  extend(SearchMethods)

  def self.queue(pool, updater)
    create({
      pool_id:         pool.id,
      post_ids:        pool.post_ids,
      updater_id:      updater.id,
      updater_ip_addr: updater.ip_addr,
      description:     pool.description,
      name:            pool.name,
      is_active:       pool.is_active?,
    })
  end

  def self.calculate_version(pool_id)
    1 + where("pool_id = ?", pool_id).maximum(:version).to_i
  end

  def fill_version
    self.version = PoolVersion.calculate_version(pool_id)
  end

  def fill_changes
    if previous
      self.added_post_ids = post_ids - previous.post_ids
      self.removed_post_ids = previous.post_ids - post_ids
    else
      self.added_post_ids = post_ids
      self.removed_post_ids = []
    end

    self.description_changed = previous.nil? || description != previous.description
    self.name_changed = previous.nil? || name != previous.name
  end

  def previous
    @previous ||= PoolVersion.where("pool_id = ? and version < ?", pool_id, version).order("version desc").first
  end

  def pool
    Pool.find(pool_id)
  end

  def updater
    User.find(updater_id)
  end

  def updater_name
    User.id_to_name(updater_id)
  end

  def pretty_name
    name&.tr("_", " ") || "(Unknown Name)"
  end

  def self.available_includes
    %i[pool updater]
  end
end
