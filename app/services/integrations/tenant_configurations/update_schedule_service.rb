# app/services/integrations/tenant_configurations/update_schedule_service.rb
module Integrations
  module TenantConfigurations
    class UpdateScheduleService
      def initialize(config, schedule_params)
        @config = config
        @schedule_params = schedule_params
      end

      def call
        # PASO 1: Validar parámetros de programación
        validation = validate_schedule_params
        return validation if validation.failure?

        # PASO 2: Actualizar programación
        if @config.update(@schedule_params)
          ServiceResult.success(
            data: @config,
            message: "Programación actualizada exitosamente"
          )
        else
          ServiceResult.failure(
            errors: @config.errors.full_messages
          )
        end

      rescue StandardError => e
        Rails.logger.error("Error al actualizar programación: #{e.message}")
        ServiceResult.failure(
          errors: [ "Error al actualizar programación: #{e.message}" ]
        )
      end

      private

      def validate_schedule_params
        # Validar frecuencia
        unless %w[daily weekly monthly].include?(@schedule_params[:sync_frequency])
          return ServiceResult.failure(
            errors: [ "Frecuencia no válida: #{@schedule_params[:sync_frequency]}" ]
          )
        end

        # Validar hora
        hour = @schedule_params[:sync_hour]
        unless hour.is_a?(Integer) && hour >= 0 && hour <= 23
          return ServiceResult.failure(
            errors: [ "Hora no válida: #{hour}" ]
          )
        end
        ServiceResult.success
      end
    end
  end
end
