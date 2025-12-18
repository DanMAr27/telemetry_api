# app/api/v1/tenant_integration_configurations.rb
module V1
  class TenantIntegrationConfigurationsApi < Grape::API
    # Helper para obtener tenant actual
    helpers do
      def current_tenant
        @current_tenant ||= Tenant.find(params[:tenant_id])
      end
    end

    resource :tenants do
      route_param :tenant_id do
        resource :integration_configurations do
          desc "Listar configuraciones de integraciones del tenant"
          params do
            optional :include_provider, type: Boolean, default: false
            optional :include_features, type: Boolean, default: false
            optional :include_computed, type: Boolean, default: true
            optional :active_only, type: Boolean, default: false
          end
          get do
            configs = current_tenant.tenant_integration_configurations
            configs = configs.active if params[:active_only]
            configs = configs.includes(:integration_provider).order(created_at: :desc)

            if params[:include_provider] || params[:include_features]
              present configs,
                      with: Entities::TenantIntegrationConfigurationEntity,
                      include_provider: params[:include_provider],
                      include_features: params[:include_features],
                      include_computed: params[:include_computed]
            else
              present configs,
                      with: Entities::TenantIntegrationConfigurationSummaryEntity
            end
          end
          desc "Obtener detalle de una configuración"
          params do
            requires :id, type: Integer
            optional :include_features, type: Boolean, default: true
            optional :include_computed, type: Boolean, default: true
            optional :include_auth_info, type: Boolean, default: false
          end
          get ":id" do
            config = current_tenant.tenant_integration_configurations.find(params[:id])

            present config,
                    with: Entities::TenantIntegrationConfigurationEntity,
                    include_features: params[:include_features],
                    include_computed: params[:include_computed],
                    include_auth_info: params[:include_auth_info]
          end
          desc "Crear nueva configuración de integración"
          params do
            requires :integration_provider_id, type: Integer, desc: "ID del proveedor"
            requires :credentials, type: Hash, desc: "Credenciales de autenticación" do
              # Dinámico según el proveedor
            end
            optional :enabled_features, type: Array[String], default: [], desc: "Features a sincronizar"
            optional :sync_frequency, type: String, values: %w[daily weekly monthly], default: "daily"
            optional :sync_hour, type: Integer, values: 0..23, default: 2
            optional :sync_day_of_week, type: Integer, values: 0..6, desc: "Solo para weekly"
            optional :sync_day_of_month, type: String, values: %w[start end], desc: "Solo para monthly"
            optional :sync_config, type: Hash, default: {}
          end
          post do
            result = Integrations::TenantConfigurations::CreateService.new(
              current_tenant,
              declared(params, include_missing: false)
            ).call

            if result.success?
              present result.data,
                      with: Entities::TenantIntegrationConfigurationEntity,
                      include_computed: true
            else
              error!({ error: "validation_error", message: result.errors.join(", ") }, 422)
            end
          end
         desc "Actualizar configuración de integración"
          params do
            requires :id, type: Integer
            optional :credentials, type: Hash
            optional :enabled_features, type: Array[String]
            optional :sync_frequency, type: String, values: %w[daily weekly monthly]
            optional :sync_hour, type: Integer, values: 0..23
            optional :sync_day_of_week, type: Integer, values: 0..6
            optional :sync_day_of_month, type: String, values: %w[start end]
            optional :sync_config, type: Hash
          end
          put ":id" do
            config = current_tenant.tenant_integration_configurations.find(params[:id])
            result = Integrations::TenantConfigurations::UpdateService.new(
              config,
              declared(params, include_missing: false)
            ).call

            if result.success?
              present result.data,
                      with: Entities::TenantIntegrationConfigurationEntity,
                      include_computed: true
            else
              error!({ error: "validation_error", message: result.errors.join(", ") }, 422)
            end
          end
          desc "Eliminar configuración de integración"
          params do
            requires :id, type: Integer
          end
          delete ":id" do
            config = current_tenant.tenant_integration_configurations.find(params[:id])
            result = Integrations::TenantConfigurations::DestroyService.new(config).call

            if result.success?
              { success: true, message: result.message }
            else
              error!({ error: "deletion_error", message: result.errors.join(", ") }, 422)
            end
          end
          desc "Activar configuración"
          params do
            requires :id, type: Integer
          end
          post ":id/activate" do
            config = current_tenant.tenant_integration_configurations.find(params[:id])
            result = Integrations::TenantConfigurations::ActivateService.new(config).call

            if result.success?
              present result.data,
                      with: Entities::TenantIntegrationConfigurationEntity,
                      include_computed: true
            else
              error!({ error: "activation_error", message: result.errors.join(", ") }, 422)
            end
          end
          desc "Desactivar configuración"
          params do
            requires :id, type: Integer
          end
          post ":id/deactivate" do
            config = current_tenant.tenant_integration_configurations.find(params[:id])
            result = Integrations::TenantConfigurations::DeactivateService.new(config).call

            if result.success?
              present result.data,
                      with: Entities::TenantIntegrationConfigurationEntity,
                      include_computed: true
            else
              error!({ error: "deactivation_error", message: result.errors.join(", ") }, 422)
            end
          end
          desc "Probar conexión con el proveedor"
          params do
            requires :integration_provider_id, type: Integer
            requires :credentials, type: Hash
          end
          post "test_connection" do
            result = Integrations::TenantConfigurations::TestConnectionService.new(
              params[:integration_provider_id],
              params[:credentials]
            ).call

            if result.success?
              present result.data, with: Entities::ConnectionTestResultEntity
            else
              error!({
                error: "connection_error",
                message: result.errors.join(", ")
              }, 422)
            end
          end
          desc "Obtener estadísticas de integraciones"
          get "stats" do
            result = Integrations::TenantConfigurations::GetStatsService.new(
              current_tenant
            ).call

            if result.success?
              present result.data, with: Entities::IntegrationStatsEntity
            else
              error!({ error: "stats_error", message: result.errors.join(", ") }, 500)
            end
          end
        end
      end
    end

    resource :integration_configurations do
      # GET /api/v1/integration_configurations/sync_schedule_options
      desc "Obtener opciones para configuración de sincronización"
      get "sync_schedule_options" do
        present({}, with: Entities::SyncScheduleOptionsEntity)
      end
    end

    resource :marketplace do
      desc "Obtener formulario de credenciales de un proveedor"
      params do
        requires :slug, type: String
      end
      get "providers/:slug/credentials_form" do
        result = Integrations::TenantConfigurations::GetCredentialsFormService.new(
          params[:slug]
        ).call

        if result.success?
          present result.data, with: Entities::CredentialsFormEntity
        else
          error!({ error: "not_found", message: result.errors.join(", ") }, 404)
        end
      end

      desc "Obtener features disponibles de un proveedor"
      params do
        requires :slug, type: String
      end
      get "providers/:slug/features" do
        provider = IntegrationProvider.for_marketplace.find_by!(slug: params[:slug])
        features = provider.integration_features.active.ordered

        present features, with: Entities::FeatureSelectionEntity
      end
    end
  end
end
