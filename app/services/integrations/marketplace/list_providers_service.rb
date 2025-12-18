# app/services/integrations/marketplace/list_providers_service.rb
module Integrations
  module Marketplace
    class ListProvidersService
      def initialize(filters = {})
        @filters = filters
      end

      def call
        providers = IntegrationProvider.for_marketplace

        # Filtrar por categoría si se especifica
        if @filters[:category_slug].present?
          category = IntegrationCategory.find_by(slug: @filters[:category_slug])
          providers = providers.where(integration_category: category) if category
        end

        # Filtrar por premium
        providers = providers.where(is_premium: @filters[:is_premium]) if @filters.key?(:is_premium)

        # Filtrar por status
        providers = providers.where(status: @filters[:status]) if @filters[:status].present?

        providers = providers.includes(:integration_features, :integration_auth_schema)

        ServiceResult.success(data: providers)
      rescue StandardError => e
        Rails.logger.error("Error al listar proveedores: #{e.message}")
        ServiceResult.failure(errors: [ "Error al cargar los proveedores" ])
      end
    end
  end
end
