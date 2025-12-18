# app/api/v1/marketplace.rb
module V1
  class MarketplaceApi < Grape::API
    resource :marketplace do
      # ========================================================================
      # GET /api/v1/marketplace
      # Listar todas las categorías con sus proveedores
      # ========================================================================
      desc "Listar todas las categorías con sus proveedores disponibles"
      get do
        result = Integrations::Marketplace::ListCategoriesService.new.call

        if result.success?
          present result.data, with: Entities::MarketplaceCategoryEntity
        else
          error!({
            error: "internal_error",
            message: result.errors.join(", ")
          }, 500)
        end
      end

      # ========================================================================
      # GET /api/v1/marketplace/categories/:slug
      # Obtener una categoría específica con sus proveedores
      # ========================================================================
      desc "Obtener detalles de una categoría específica"
      params do
        requires :slug, type: String, desc: "Slug de la categoría"
      end
      get "categories/:slug" do
        result = Integrations::Marketplace::GetCategoryService.new(params[:slug]).call

        if result.success?
          present result.data, with: Entities::MarketplaceCategoryEntity
        else
          error!({
            error: "not_found",
            message: result.errors.join(", ")
          }, 404)
        end
      end

      # ========================================================================
      # GET /api/v1/marketplace/providers
      # Listar todos los proveedores (con filtros opcionales)
      # ========================================================================
      desc "Listar todos los proveedores disponibles"
      params do
        optional :category_slug, type: String, desc: "Filtrar por categoría"
        optional :is_premium, type: Boolean, desc: "Filtrar por premium"
        optional :status, type: String, values: %w[active beta], desc: "Filtrar por estado"
      end
      get "providers" do
        filters = {
          category_slug: params[:category_slug],
          is_premium: params[:is_premium],
          status: params[:status]
        }.compact

        result = Integrations::Marketplace::ListProvidersService.new(filters).call

        if result.success?
          present result.data, with: Entities::MarketplaceProviderEntity, include_auth: true
        else
          error!({
            error: "internal_error",
            message: result.errors.join(", ")
          }, 500)
        end
      end

      # ========================================================================
      # GET /api/v1/marketplace/providers/:slug
      # Obtener detalles de un proveedor específico
      # ========================================================================
      desc "Obtener detalles de un proveedor específico"
      params do
        requires :slug, type: String, desc: "Slug del proveedor (ej: geotab)"
      end
      get "providers/:slug" do
        result = Integrations::Marketplace::GetProviderService.new(params[:slug]).call

        if result.success?
          present result.data, with: Entities::MarketplaceProviderEntity, include_auth: true
        else
          error!({
            error: "not_found",
            message: result.errors.join(", ")
          }, 404)
        end
      end
    end
  end
end
