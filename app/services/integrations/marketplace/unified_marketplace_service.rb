# app/services/integrations/marketplace/unified_marketplace_service.rb
module Integrations
  module Marketplace
    class UnifiedMarketplaceService
      def initialize(filters = {})
        @view = filters[:view] || "grouped"
        @category_slug = filters[:category_slug]
        @provider_status = filters[:provider_status]
        @is_premium = filters[:is_premium]
        @search = filters[:search]
        @include_features = filters[:include_features]
        @include_auth_info = filters[:include_auth_info]
        @include_stats = filters[:include_stats]
      end

      def call
        case @view
        when "grouped"
          get_grouped_marketplace
        when "flat"
          get_flat_marketplace
        when "category_detail"
          get_category_detail
        else
          ServiceResult.failure(errors: [ "Vista no válida: #{@view}" ])
        end
      rescue StandardError => e
        Rails.logger.error("Error en UnifiedMarketplaceService: #{e.message}")
        ServiceResult.failure(errors: [ "Error al cargar el marketplace: #{e.message}" ])
      end

      private

      def get_grouped_marketplace
        # Obtener categorías activas
        categories = IntegrationCategory.active.ordered

        # Aplicar filtro de categoría específica si existe
        categories = categories.where(slug: @category_slug) if @category_slug.present?

        # Aplicar búsqueda
        categories = apply_search_to_categories(categories) if @search.present?

        # Precargar relaciones
        categories = categories.includes(
          integration_providers: [ :integration_features, :integration_auth_schema ]
        )

        # Filtrar proveedores dentro de cada categoría
        categories_data = categories.map do |category|
          providers = filter_providers(category.integration_providers.for_marketplace)

          # Solo incluir categorías que tienen proveedores después del filtrado
          next if providers.empty?

          {
            category: category,
            providers: providers
          }
        end.compact

        ServiceResult.success(
          data: {
            categories: categories_data.map { |c| c[:category] },
            total_categories: categories_data.count,
            total_providers: categories_data.sum { |c| c[:providers].count }
          }
        )
      end

      def get_flat_marketplace
        # Obtener todos los proveedores activos
        providers = IntegrationProvider.for_marketplace

        # Filtrar por categoría
        if @category_slug.present?
          category = IntegrationCategory.find_by(slug: @category_slug)
          providers = providers.where(integration_category: category) if category
        end

        # Aplicar filtros
        providers = filter_providers(providers)

        # Aplicar búsqueda
        providers = apply_search_to_providers(providers) if @search.present?

        # Precargar relaciones
        providers = providers.includes(
          :integration_category,
          :integration_features,
          :integration_auth_schema
        )

        ServiceResult.success(
          data: {
            providers: providers,
            total_providers: providers.count,
            filters_applied: active_filters
          }
        )
      end

      def get_category_detail
        unless @category_slug.present?
          return ServiceResult.failure(
            errors: [ "Se requiere 'category_slug' para la vista category_detail" ]
          )
        end

        category = IntegrationCategory
          .active
          .includes(integration_providers: [ :integration_features, :integration_auth_schema ])
          .find_by(slug: @category_slug)

        unless category
          return ServiceResult.failure(
            errors: [ "Categoría '#{@category_slug}' no encontrada" ]
          )
        end

        # Filtrar proveedores
        providers = filter_providers(category.integration_providers.for_marketplace)

        ServiceResult.success(
          data: {
            category: category,
            providers: providers,
            providers_count: providers.count
          }
        )
      end

      def filter_providers(providers)
        # Filtrar por estado
        if @provider_status.present?
          providers = providers.where(status: @provider_status)
        end

        # Filtrar por premium
        unless @is_premium.nil?
          providers = providers.where(is_premium: @is_premium)
        end

        providers
      end

      def apply_search_to_providers(providers)
        search_term = "%#{@search}%"
        providers.where(
          "integration_providers.name ILIKE :term OR integration_providers.description ILIKE :term",
          term: search_term
        )
      end

      def apply_search_to_categories(categories)
        search_term = "%#{@search}%"
        categories.where(
          "integration_categories.name ILIKE :term OR integration_categories.description ILIKE :term",
          term: search_term
        )
      end

      def active_filters
        {
          view: @view,
          category_slug: @category_slug,
          provider_status: @provider_status,
          is_premium: @is_premium,
          search: @search
        }.compact
      end
    end
  end
end
