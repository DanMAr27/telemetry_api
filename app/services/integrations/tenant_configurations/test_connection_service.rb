# app/services/integrations/tenant_configurations/test_connection_service.rb
module Integrations
  module TenantConfigurations
    class TestConnectionService
      def initialize(provider_id, credentials)
        @provider_id = provider_id
        @credentials = credentials
      end

      def call
        # PASO 1: Validar proveedor
        provider = validate_provider
        return provider unless provider.is_a?(IntegrationProvider)

        # PASO 2: Verificar que tenga conector implementado
        unless Factories::ConnectorFactory.provider_available?(provider.slug)
          return ServiceResult.failure(
            errors: [ "El proveedor no tiene conector implementado aún" ]
          )
        end

        # PASO 3: Crear configuración temporal (NO se guarda en BD)
        temp_config = build_temp_config(provider)

        # PASO 4: Intentar autenticar
        test_authentication(temp_config, provider)

      rescue StandardError => e
        Rails.logger.error("Error en test de conexión: #{e.message}")
        ServiceResult.failure(
          errors: [ "Error al probar conexión: #{e.message}" ]
        )
      end

      private

      def validate_provider
        provider = IntegrationProvider.find_by(id: @provider_id)

        unless provider
          return ServiceResult.failure(
            errors: [ "Proveedor no encontrado" ]
          )
        end

        unless provider.available?
          return ServiceResult.failure(
            errors: [ "El proveedor no está disponible" ]
          )
        end

        provider
      end

      def build_temp_config(provider)
        # Crear instancia SIN guardar en BD
        TenantIntegrationConfiguration.new(
          integration_provider: provider,
          credentials: @credentials,
          is_active: false # No está activa, es solo para test
        )
      end


      def test_authentication(temp_config, provider)
        Rails.logger.info("→ Probando conexión con #{provider.name}...")
        connector = ConnectorFactory.build(provider.slug, temp_config)
        auth_result = connector.authenticate

        if auth_result
          Rails.logger.info("✓ Conexión exitosa con #{provider.name}")

          ServiceResult.success(
            data: {
              success: true,
              provider_name: provider.name,
              provider_slug: provider.slug,
              message: "Conexión establecida exitosamente",
              tested_at: Time.current
            }
          )
        else
          ServiceResult.failure(
            errors: [ "No se pudo establecer conexión con #{provider.name}" ]
          )
        end

      rescue Integrations::Connectors::BaseConnector::AuthenticationError => e
        Rails.logger.error("✗ Test de conexión falló: #{e.message}")

        ServiceResult.failure(
          errors: [ "Credenciales inválidas: #{e.message}" ]
        )

      rescue Integrations::Connectors::BaseConnector::ApiError => e
        Rails.logger.error("✗ Error de API: #{e.message}")

        ServiceResult.failure(
          errors: [ "Error de conexión: #{e.message}" ]
        )

      rescue StandardError => e
        Rails.logger.error("✗ Error inesperado: #{e.message}")

        ServiceResult.failure(
          errors: [ "Error al probar conexión: #{e.message}" ]
        )
      end
    end
  end
end
