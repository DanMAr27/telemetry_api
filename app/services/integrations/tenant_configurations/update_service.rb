# app/services/integrations/tenant_configurations/update_service.rb
module Integrations
  module TenantConfigurations
    class UpdateService
      def initialize(config, params)
        @config = config
        @params = params
      end

      def call
        # Si se actualizan credenciales, marcar para revalidación
        if @params.key?(:credentials) && @params[:credentials] != @config.credentials
          @params[:last_sync_status] = nil
          @params[:last_sync_error] = nil
        end

        if @config.update(@params)
          ServiceResult.success(
            data: @config,
            message: "Configuración actualizada exitosamente"
          )
        else
          ServiceResult.failure(errors: @config.errors.full_messages)
        end
      rescue StandardError => e
        Rails.logger.error("Error al actualizar configuración: #{e.message}")
        ServiceResult.failure(errors: [ "Error al actualizar la configuración" ])
      end
    end
  end
end
