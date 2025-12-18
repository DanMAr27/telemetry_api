# app/services/integrations/tenant_configurations/get_stats_service.rb
module Integrations
  module TenantConfigurations
    class GetStatsService
      def initialize(tenant)
        @tenant = tenant
      end

      def call
        configs = @tenant.tenant_integration_configurations

        stats = {
          total_configurations: configs.count,
          active_configurations: configs.active.count,
          inactive_configurations: configs.inactive.count,
          configurations_with_errors: configs.with_errors.count,
          total_syncs_today: 0, # TODO: Implementar cuando tengamos sync_logs
          successful_syncs_today: 0,
          failed_syncs_today: 0,
          last_sync_time: configs.maximum(:last_sync_at),
          by_provider: configs.group(:integration_provider_id).count,
          frequency_distribution: configs.group(:sync_frequency).count
        }

        ServiceResult.success(data: stats)
      rescue StandardError => e
        Rails.logger.error("Error al obtener estadísticas: #{e.message}")
        ServiceResult.failure(errors: [ "Error al cargar las estadísticas" ])
      end
    end
  end
end
