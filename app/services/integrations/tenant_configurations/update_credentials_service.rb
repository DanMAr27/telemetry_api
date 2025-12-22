# app/services/integrations/tenant_configurations/update_credentials_service.rb
module Integrations
  module TenantConfigurations
    class UpdateCredentialsService
      def initialize(config, new_credentials, test_connection: false)
        @config = config
        @new_credentials = new_credentials
        @test_connection = test_connection
        @was_active = config.is_active
      end

      def call
        # PASO 1: Validar estructura de credenciales
        validation = validate_credentials_structure
        return validation if validation.failure?

        # PASO 2: Si está activa, desactivar temporalmente
        @config.update!(is_active: false) if @was_active

        # PASO 3: Actualizar credenciales
        unless @config.update(credentials: @new_credentials)
          return ServiceResult.failure(
            errors: @config.errors.full_messages
          )
        end

        # PASO 4: Limpiar estado de última sync
        @config.update!(last_sync_status: nil, last_sync_error: nil)

        # PASO 5: Probar conexión si se solicita
        if @test_connection
          test_result = test_new_connection
          return test_result if test_result.failure?
        end

        # PASO 6: Re-activar si estaba activa
        @config.update!(is_active: true) if @was_active

        ServiceResult.success(
          data: @config,
          message: "Credenciales actualizadas exitosamente"
        )

      rescue StandardError => e
        Rails.logger.error("Error al actualizar credenciales: #{e.message}")
        ServiceResult.failure(
          errors: [ "Error al actualizar credenciales: #{e.message}" ]
        )
      end

      private

      def validate_credentials_structure
        schema = @config.integration_provider.integration_auth_schema
        return ServiceResult.failure(errors: [ "Proveedor sin schema de autenticación" ]) unless schema

        required_fields = schema.required_fields.map { |f| f["name"] }
        missing_fields = required_fields - @new_credentials.keys.map(&:to_s)

        if missing_fields.any?
          return ServiceResult.failure(
            errors: [ "Faltan campos requeridos: #{missing_fields.join(', ')}" ]
          )
        end

        ServiceResult.success
      end

      def test_new_connection
        result = TestConnectionService.new(
          @config.integration_provider.id,
          @new_credentials
        ).call

        unless result.success?
          return ServiceResult.failure(
            errors: [ "Test de conexión falló: #{result.errors.join(', ')}" ]
          )
        end

        ServiceResult.success
      end
    end
  end
end
