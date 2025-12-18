# app/services/integrations/marketplace/get_category_service.rb
module Integrations
  module Marketplace
    class GetCategoryService
      def initialize(slug)
        @slug = slug
      end

      def call
        category = IntegrationCategory
          .active
          .includes(integration_providers: [ :integration_features, :integration_auth_schema ])
          .find_by!(slug: @slug)

        ServiceResult.success(data: category)
      rescue ActiveRecord::RecordNotFound
        ServiceResult.failure(errors: [ "Categoría no encontrada" ])
      rescue StandardError => e
        Rails.logger.error("Error al obtener categoría #{@slug}: #{e.message}")
        ServiceResult.failure(errors: [ "Error al cargar la categoría" ])
      end
    end
  end
end
