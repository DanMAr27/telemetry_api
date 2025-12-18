# app/services/integrations/tenant_configurations/test_connection_service.rb
module Integrations
  module TenantConfigurations
    class TestConnectionService
      def initialize(provider_id, credentials)
        @provider_id = provider_id
        @credentials = credentials
      end

      def call
        provider = IntegrationProvider.find(@provider_id)

        # Validar estructura de credenciales
        validation_result = validate_credentials_structure(provider, @credentials)
        return validation_result unless validation_result.success?

        # Obtener el conector apropiado
        connector = get_connector(provider.slug)

        # Probar conexión
        result = connector.test_connection(@credentials)

        if result[:success]
          ServiceResult.success(
            data: {
              success: true,
              message: "Conexión establecida exitosamente",
              provider_name: provider.name,
              details: result[:details]
            }
          )
        else
          ServiceResult.failure(
            errors: [ result[:error] || "Error al conectar con el proveedor" ]
          )
        end
      rescue StandardError => e
        Rails.logger.error("Error al probar conexión: #{e.message}")
        ServiceResult.failure(
          errors: [ "Error al probar conexión: #{e.message}" ]
        )
      end

      private

      def validate_credentials_structure(provider, credentials)
        schema = provider.integration_auth_schema
        return ServiceResult.failure(errors: [ "Proveedor sin schema de autenticación" ]) unless schema

        required_fields = schema.required_fields.map { |f| f["name"] }
        missing_fields = required_fields - credentials.keys.map(&:to_s)

        if missing_fields.any?
          return ServiceResult.failure(
            errors: [ "Faltan campos requeridos: #{missing_fields.join(', ')}" ]
          )
        end

        ServiceResult.success
      end

      def get_connector(provider_slug)
        # Factory pattern para obtener el conector correcto
        # Por ahora retornamos un mock connector
        # En Fase 3 se implementarán los conectores reales
        case provider_slug
        when "geotab"
          Integrations::Connectors::GeotabConnector.new
        when "verizon_connect"
          Integrations::Connectors::VerizonConnector.new
        when "tomtom_telematics"
          Integrations::Connectors::TomtomConnector.new
        else
          Integrations::Connectors::MockConnector.new
        end
      end
    end
  end
end
