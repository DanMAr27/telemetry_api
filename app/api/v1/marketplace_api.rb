# app/api/v1/marketplace.rb
module V1
  class MarketplaceApi < Grape::API
    resource :marketplace do
      desc "Obtener marketplace de integraciones (categorías y proveedores)" do
        detail "Endpoint flexible que retorna el marketplace completo o filtrado según parámetros"
      end
      params do
        # Filtros de visualización
        optional :view, type: String,
                 values: %w[grouped flat category_detail],
                 default: "grouped",
                 desc: "Modo de visualización: grouped (categorías), flat (lista), category_detail (una categoría)"

        # Filtros de categoría
        optional :category_slug, type: String,
                 desc: "Filtrar por slug de categoría (ej: telemetry)"

        # Filtros de proveedores
        optional :provider_status, type: String,
                 values: %w[active beta coming_soon],
                 desc: "Filtrar proveedores por estado"

        optional :is_premium, type: Boolean,
                 desc: "Filtrar solo proveedores premium (true) o gratuitos (false)"

        optional :search, type: String,
                 desc: "Buscar por nombre de proveedor o categoría"

        # Opciones de inclusión
        optional :include_features, type: Boolean,
                 default: true,
                 desc: "Incluir features de cada proveedor"

        optional :include_auth_info, type: Boolean,
                 default: false,
                 desc: "Incluir información de autenticación"

        optional :include_stats, type: Boolean,
                 default: false,
                 desc: "Incluir estadísticas de uso"
      end
      get do
        result = Integrations::Marketplace::UnifiedMarketplaceService.new(
          view: params[:view],
          category_slug: params[:category_slug],
          provider_status: params[:provider_status],
          is_premium: params[:is_premium],
          search: params[:search],
          include_features: params[:include_features],
          include_auth_info: params[:include_auth_info],
          include_stats: params[:include_stats]
        ).call

        if result.success?
          # Adaptar la respuesta según el view mode
          case params[:view]
          when "grouped"
            present result.data[:categories],
                    with: Entities::MarketplaceCategoryEntity,
                    include_features: params[:include_features],
                    include_auth_info: params[:include_auth_info]

          when "flat"
            present result.data[:providers],
                    with: Entities::MarketplaceProviderEntity,
                    include_features: params[:include_features],
                    include_auth_info: params[:include_auth_info],
                    include_stats: params[:include_stats]

          when "category_detail"
            present result.data[:category],
                    with: Entities::MarketplaceCategoryEntity,
                    include_features: params[:include_features],
                    include_auth_info: params[:include_auth_info]
          end
        else
          error!({
            error: "marketplace_error",
            message: result.errors.join(", ")
          }, 500)
        end
      end

      desc "Obtener detalle completo de un proveedor específico"
      params do
        requires :slug, type: String, desc: "Slug del proveedor (ej: geotab)"
        optional :include_category, type: Boolean, default: true
        optional :include_features, type: Boolean, default: true
        optional :include_auth_info, type: Boolean, default: true
        optional :include_stats, type: Boolean, default: true
      end
      get "providers/:slug" do
        provider = IntegrationProvider
          .for_marketplace
          .includes(:integration_category, :integration_features, :integration_auth_schema)
          .find_by!(slug: params[:slug])

        present provider,
                with: Entities::MarketplaceProviderEntity,
                include_category: params[:include_category],
                include_features: params[:include_features],
                include_auth_info: params[:include_auth_info],
                include_stats: params[:include_stats]
      rescue ActiveRecord::RecordNotFound
        error!({
          error: "not_found",
          message: "Proveedor no encontrado"
        }, 404)
      end

      desc "Obtener formulario completo para configurar un proveedor"
      params do
        requires :slug, type: String, desc: "Slug del proveedor"
      end
      get "providers/:slug/configuration_form" do
        provider = IntegrationProvider
          .for_marketplace
          .includes(:integration_features, :integration_auth_schema)
          .find_by!(slug: params[:slug])

        unless provider.integration_auth_schema&.is_active
          error!({
            error: "configuration_unavailable",
            message: "Este proveedor no tiene configuración de autenticación disponible"
          }, 422)
        end

        present provider, with: Entities::ConfigurationFormEntity
      rescue ActiveRecord::RecordNotFound
        error!({
          error: "not_found",
          message: "Proveedor no encontrado"
        }, 404)
      end

      desc "Obtener lista de empresas/tenants disponibles"
      params do
        optional :exclude_configured_for, type: String,
                 desc: "Excluir tenants que ya tienen este proveedor configurado"
      end
      get "available_tenants" do
        tenants = Tenant.active.order(:name)

        if params[:exclude_configured_for].present?
          provider = IntegrationProvider.find_by(slug: params[:exclude_configured_for])

          if provider
            configured_tenant_ids = TenantIntegrationConfiguration
              .where(integration_provider: provider)
              .pluck(:tenant_id)

            tenants = tenants.where.not(id: configured_tenant_ids)
          end
        end

        present tenants, with: Entities::TenantSummaryEntity
      end

      desc "Configurar una integración desde el marketplace"
      params do
        requires :tenant_id, type: Integer
        requires :provider_slug, type: String
        requires :credentials, type: Hash
        requires :enabled_features, type: Array[String]
        optional :sync_frequency, type: String, values: %w[daily weekly monthly], default: "daily"
        optional :sync_hour, type: Integer, values: 0..23, default: 2
        optional :sync_day_of_week, type: Integer, values: 0..6
        optional :sync_day_of_month, type: String, values: %w[start end]
        optional :test_connection_first, type: Boolean, default: false
        optional :activate_immediately, type: Boolean, default: false
      end
      post "setup" do
        tenant = Tenant.find(params[:tenant_id])

        result = Integrations::Marketplace::SetupIntegrationService.new(
          tenant,
          params[:provider_slug],
          declared(params, include_missing: false).except(:tenant_id, :provider_slug)
        ).call

        if result.success?
          present result.data,
                  with: Entities::TenantIntegrationConfigurationEntity,
                  include_computed: true,
                  include_provider: true,
                  include_features: true
        else
          error!({
            error: "setup_failed",
            message: result.errors.join(", ")
          }, 422)
        end
      rescue ActiveRecord::RecordNotFound
        error!({
          error: "tenant_not_found",
          message: "Empresa/Tenant no encontrada"
        }, 404)
      end

      desc "Probar conexión con un proveedor sin crear configuración"
      params do
        requires :provider_slug, type: String
        requires :credentials, type: Hash
      end
      post "test_connection" do
        provider = IntegrationProvider.for_marketplace.find_by!(slug: params[:provider_slug])

        result = Integrations::TenantConfigurations::TestConnectionService.new(
          provider.id,
          params[:credentials]
        ).call

        if result.success?
          present result.data, with: Entities::ConnectionTestResultEntity
        else
          error!({
            error: "connection_failed",
            message: result.errors.join(", ")
          }, 422)
        end
      rescue ActiveRecord::RecordNotFound
        error!({
          error: "provider_not_found",
          message: "Proveedor no encontrado"
        }, 404)
      end
    end
  end
end
