require_relative "document_store/model" # due to some fuckery we have to force load the file the client is defined in

class SystemInfo
  def load_all
    reports
    postgres
    redis
    memcached
    elasticsearch
    git
    self
  end

  def reports
    @reports ||= begin
     data = Reports.get_stats
     RecursiveOpenStruct.new(date: { code: data["date"], db: data["dbDate"] }, version: { schema: data["schemaVersion"], db: data["dbVersion"] }, health: { healthy: data["healthy"], error: data["error"] }, latency: data["latency"])
    end
  end

  def postgres
    @postgres ||= begin
      sql = <<~SQL.squish
                      SELECT TO_CHAR(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS date,
                          dbstats.numbackends AS connection_count,
                          dbstats.deadlocks,
                          version(),
                          schema_migrations.version as latest_migration,
                          schema_migrations_count.count as migration_count
                      FROM LATERAL (
                          SELECT numbackends, deadlocks
                          FROM pg_stat_database
                          WHERE datname = '#{ApplicationRecord.connection.current_database}'
                      ) dbstats,
                      LATERAL (
                        SELECT version
                        FROM schema_migrations
                        ORDER BY version DESC
                        LIMIT 1
                      ) schema_migrations,
                      LATERAL (
                        SELECT COUNT(*) as count FROM schema_migrations
                      ) schema_migrations_count
                    SQL
      data = ApplicationRecord.connection.execute(sql).first
      latency = time { ApplicationRecord.connection.execute("SELECT 1").first }
      pending_migrations = false
      begin
        ActiveRecord::Migration.check_all_pending!
      rescue ActiveRecord::PendingMigrationError
        pending_migrations = true
      end
      RecursiveOpenStruct.new(date: data["date"], connection_count: data["connection_count"], deadlocks: data["deadlocks"], version: data["version"], latency: latency, database: ApplicationRecord.connection.current_database, latest_migration: data["latest_migration"], latest_migration_date: Time.strptime(data["latest_migration"], "%Y%m%d%H%M%S"),  migration_count: data["migration_count"], pending_migrations: pending_migrations)
    end
  end

  def redis
    @redis ||= begin
      latency = time { Cache.redis.ping }
      current_db = Cache.redis.client("INFO").match(%r/db=(\d+)/)[1]
      info = Cache.redis.info
      version = info["redis_version"]
      connected_clients = info["connected_clients"].to_i
      clients_per_db = Cache.redis.client("LIST").split("\n").map { |l| l.match(/db=(\d+)/)[1] }.tally
      keys_per_db = Cache.redis.info("KEYSPACE").to_h { |k, v| [k[2..], v.match(/keys=(\d+)/)[1].to_i] }
      RecursiveOpenStruct.new(latency: latency, current_db: current_db, version: version, connected_clients: connected_clients, clients_per_db: clients_per_db, keys_per_db: keys_per_db, databases: keys_per_db.keys)
    end
  end

  def memcached
    @memcached ||= begin
      RecursiveOpenStruct.new(FemboyFans.config.memcached_servers.split.to_h do |server|
        client = Dalli::Client.new(server)
        version = client.version.values.first
        connections = client.stats.values.first["curr_connections"].to_i
        latency = time { client.version }
        [server, { version: version, connections: connections, latency: latency }]
      end)
    end
  end

  def elasticsearch
    @elasticsearch ||= begin
      info = DocumentStore.client.info
      version = info["version"]["number"]
      latency = time { DocumentStore.client.ping }
      indexes = DocumentStore.client.cat.indices(h: "index,docs.count", format: "json").map do |r|
        { name: r["index"], docs: r["docs.count"].to_i }
      end
      health = DocumentStore.client.cat.health(format: "json").first
      RecursiveOpenStruct.new(version: version, latency: latency, indexes: indexes.pluck(:name), docs_per_index: indexes.map { |i| [i[:name], i[:docs]] }.to_h, date: Time.at(health["epoch"].to_i).utc.iso8601, status: health["status"])
    end
  end

  def git
    @git ||= GitHelper.instance
  end

  def misc
    @misc ||= begin
      RecursiveOpenStruct.new(ruby_version: RUBY_VERSION, rails_version: Rails.version, node_version: `node --version`.strip, alpine_version: File.read("/etc/alpine-release").strip, environment: Rails.env, hostname: FemboyFans.config.hostname, name: FemboyFans.config.app_name, url: FemboyFans.config.app_url, description: FemboyFans.config.description, safe_mode: FemboyFans.config.safe_mode?, version: FemboyFans.config.version, date: Time.now.utc.iso8601, timezone: Time.now.zone)
    end
  end

  private

  def time(&block)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    block.call
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
  end
end
