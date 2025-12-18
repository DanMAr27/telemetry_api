# app/services/integrations/tenant_configurations/activate_service.rb
module Integrations
  module TenantConfigurations
    class ActivateService
      def initialize(config)
        @config = config
      end

      def call
        # Validar que tenga credenciales
        unless @config.credentials.present?
          return ServiceResult.failure(
            errors: [ "Debe configurar las credenciales antes de activar" ]
          )
        end

        # Validar que tenga al menos una feature habilitada
        unless @config.enabled_features.any?
          return ServiceResult.failure(
            errors: [ "Debe seleccionar al menos una funcionalidad a sincronizar" ]
          )
        end

        if @config.activate!
          ServiceResult.success(
            data: @config,
            message: "Configuración activada exitosamente"
          )
        else
          ServiceResult.failure(errors: @config.errors.full_messages)
        end
      rescue StandardError => e
        Rails.logger.error("Error al activar configuración: #{e.message}")
        ServiceResult.failure(errors: [ "Error al activar la configuración" ])
      end
    end
  end
end
