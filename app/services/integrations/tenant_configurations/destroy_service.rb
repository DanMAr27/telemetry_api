# app/services/integrations/tenant_configurations/destroy_service.rb
module Integrations
  module TenantConfigurations
    class DestroyService
      def initialize(config)
        @config = config
      end

      def call
        # Validar que esté inactiva antes de eliminar
        if @config.is_active
          return ServiceResult.failure(
            errors: [ "Debe desactivar la configuración antes de eliminarla" ]
          )
        end

        if @config.destroy
          ServiceResult.success(message: "Configuración eliminada exitosamente")
        else
          ServiceResult.failure(errors: @config.errors.full_messages)
        end
      rescue StandardError => e
        Rails.logger.error("Error al eliminar configuración: #{e.message}")
        ServiceResult.failure(errors: [ "Error al eliminar la configuración" ])
      end
    end
  end
end
