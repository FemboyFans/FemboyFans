# frozen_string_literal: true

def cache_store
  if Rails.env.test? || FemboyFans.config.memcached_servers.blank?
    [:memory_store, { size: 32.megabytes }]
  elsif FemboyFans.config.disable_cache_store?
    :null_store
  else
    # this must be static else setup is not possible without pre-populating the config table externally
    [:mem_cache_store, FemboyFans.config.memcached_servers, { namespace: "FemboyFans" }]
  end
end

Rails.application.configure do
  config.cache_store = cache_store
  config.action_controller.cache_store = cache_store
  Rails.cache = ActiveSupport::Cache.lookup_store(Rails.application.config.cache_store)
end
