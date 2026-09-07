# frozen_string_literal: true

module Migrations
  module ConfigOverride
    extend(ActiveSupport::Concern)

    module ClassMethods
      def with_config_override!(table = "config", model = :Config)
        klass = Class.new(ApplicationRecord) do
          self.table_name = table

          def self.config_id
            GayFurCity.config.config_id
          end

          def self.get
            find_or_create_by!(id: config_id)
          end

          def self.delete_cache
            Cache.delete("admin_config:#{config_id}")
            Cache.delete("admin_config:hash_columns")
          end
        end
        return yield(klass) if block_given?
        Object.send(:remove_const, model) if Object.constants.include?(model)
        Object.const_set(model, klass)
        klass
      end

      def with_admin_config_override!(&)
        with_config_override!("admin_config", :AdminConfig, &)
      end
    end
  end

  ActiveRecord::Migration.include(ConfigOverride)
end
