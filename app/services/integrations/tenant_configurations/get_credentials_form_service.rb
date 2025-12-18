# app/services/integrations/tenant_configurations/get_credentials_form_service.rb
module Integrations
  module TenantConfigurations
    class GetCredentialsFormService
      def initialize(provider_slug)
        @provider_slug = provider_slug
      end

      def call
        provider = IntegrationProvider.for_marketplace.find_by(slug: @provider_slug)

        unless provider
          return ServiceResult.failure(errors: [ "Proveedor no encontrado" ])
        end

        unless provider.integration_auth_schema
          return ServiceResult.failure(errors: [ "Proveedor sin configuración de autenticación" ])
        end

        ServiceResult.success(data: provider)
      rescue StandardError => e
        Rails.logger.error("Error al obtener formulario: #{e.message}")
        ServiceResult.failure(errors: [ "Error al cargar el formulario" ])
      end
    end
  end
end
