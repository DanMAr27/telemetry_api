# app/services/integrations/tenant_configurations/update_features_service.rb
module Integrations
  module TenantConfigurations
    class UpdateFeaturesService
      def initialize(config, enabled_features)
        @config = config
        @enabled_features = enabled_features
      end

      def call
        # PASO 1: Validar que las features existan
        validation = validate_features
        return validation if validation.failure?

        # PASO 2: Actualizar features
        if @config.update(enabled_features: @enabled_features)
          ServiceResult.success(
            data: @config,
            message: "Features actualizadas exitosamente"
          )
        else
          ServiceResult.failure(
            errors: @config.errors.full_messages
          )
        end

      rescue StandardError => e
        Rails.logger.error("Error al actualizar features: #{e.message}")
        ServiceResult.failure(
          errors: [ "Error al actualizar features: #{e.message}" ]
        )
      end

      private

      def validate_features
        unless @enabled_features.is_a?(Array)
          return ServiceResult.failure(
            errors: [ "enabled_features debe ser un array" ]
          )
        end

        available_features = @config.integration_provider.integration_features.active.pluck(:feature_key)
        invalid_features = @enabled_features - available_features

        if invalid_features.any?
          return ServiceResult.failure(
            errors: [ "Features no disponibles: #{invalid_features.join(', ')}" ],
            data: { available_features: available_features }
          )
        end

        ServiceResult.success
      end
    end
  end
end
