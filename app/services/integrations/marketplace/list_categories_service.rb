# app/services/integrations/marketplace/list_categories_service.rb
module Integrations
  module Marketplace
    class ListCategoriesService
      def call
        categories = IntegrationCategory
          .for_marketplace
          .includes(integration_providers: [ :integration_features, :integration_auth_schema ])

        ServiceResult.success(data: categories)
      rescue StandardError => e
        Rails.logger.error("Error al listar categorías del marketplace: #{e.message}")
        ServiceResult.failure(errors: [ "Error al cargar el marketplace" ])
      end
    end
  end
end
