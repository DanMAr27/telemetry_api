# app/api/entities/integration_stats_entity.rb
module Entities
  class IntegrationStatsEntity < Grape::Entity
    expose :total_configurations
    expose :active_configurations
    expose :inactive_configurations
    expose :configurations_with_errors
    expose :total_syncs_today
    expose :successful_syncs_today
    expose :failed_syncs_today
    expose :last_sync_time

    expose :configurations_by_provider do |stats, _options|
      stats[:by_provider]
    end

    expose :sync_frequency_distribution do |stats, _options|
      stats[:frequency_distribution]
    end
  end
end
