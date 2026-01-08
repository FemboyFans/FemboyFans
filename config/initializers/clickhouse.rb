# frozen_string_literal: true

require_relative("../../app/logical/reports")

if Reports.enabled?
  ClickHouse.config do |config|
    config.url = FemboyFans.config.clickhouse_url
  end
end
