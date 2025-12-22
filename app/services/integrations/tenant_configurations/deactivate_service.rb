# app/services/integrations/tenant_configurations/deactivate_service.rb
module Integrations
  module TenantConfigurations
    class DeactivateService
      def initialize(config)
        @config = config
      end

      def call
        if @config.deactivate!
          ServiceResult.success(
            data: @config,
            message: "Configuración desactivada. Los datos históricos se mantienen."
          )
        else
          ServiceResult.failure(errors: @config.errors.full_messages)
        end
      rescue StandardError => e
        Rails.logger.error("Error al desactivar configuración: #{e.message}")
        ServiceResult.failure(errors: [ "Error al desactivar la configuración" ])
      end
    end
  end
end
