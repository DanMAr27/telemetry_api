# app/services/integrations/marketplace/get_provider_service.rb
module Integrations
  module Marketplace
    class GetProviderService
      def initialize(slug)
        @slug = slug
      end

      def call
        provider = IntegrationProvider
          .for_marketplace
          .includes(:integration_features, :integration_auth_schema, :integration_category)
          .find_by!(slug: @slug)

        ServiceResult.success(data: provider)
      rescue ActiveRecord::RecordNotFound
        ServiceResult.failure(errors: [ "Proveedor no encontrado" ])
      rescue StandardError => e
        Rails.logger.error("Error al obtener proveedor #{@slug}: #{e.message}")
        ServiceResult.failure(errors: [ "Error al cargar el proveedor" ])
      end
    end
  end
end
