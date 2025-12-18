# app/api/v1/integration_configurations_api.rb (MEJORADA)
module V1
  class IntegrationConfigurationsApi < Grape::API
    resource :integration_configurations do
      desc "Listar configuraciones de integraciones"
      params do
        optional :tenant_id, type: Integer, desc: "Filtrar por tenant"
        optional :provider_slug, type: String, desc: "Filtrar por proveedor"
        optional :is_active, type: Boolean, desc: "Filtrar por estado activo"
        optional :status, type: String, values: %w[success error], desc: "Filtrar por último estado de sync"
        optional :page, type: Integer, default: 1
        optional :per_page, type: Integer, default: 50, values: 1..100
      end
      get do
        configs = TenantIntegrationConfiguration.includes(:integration_provider, :tenant)

        # Aplicar filtros
        configs = configs.where(tenant_id: params[:tenant_id]) if params[:tenant_id]
        configs = configs.where(is_active: params[:is_active]) unless params[:is_active].nil?
        configs = configs.where(last_sync_status: params[:status]) if params[:status]

        if params[:provider_slug]
          configs = configs.joins(:integration_provider)
            .where(integration_providers: { slug: params[:provider_slug] })
        end

        # Ordenar
        configs = configs.order(created_at: :desc)

        # Paginación
        total = configs.count
        configs = configs.offset((params[:page] - 1) * params[:per_page])
                        .limit(params[:per_page])

        {
          configurations: Entities::TenantIntegrationConfigurationSummaryEntity.represent(configs),
          pagination: {
            current_page: params[:page],
            per_page: params[:per_page],
            total_items: total,
            total_pages: (total.to_f / params[:per_page]).ceil
          }
        }
      end

      desc "Obtener detalle completo de una configuración"
      params do
        requires :id, type: Integer
      end
      get ":id" do
        config = TenantIntegrationConfiguration.find(params[:id])

        present config,
                with: Entities::TenantIntegrationConfigurationEntity,
                include_provider: true,
                include_tenant: true,
                include_features: true,
                include_computed: true
      end

      # Bloque 1: Actualizar Credenciales
      desc "Actualizar solo las credenciales de autenticación"
      params do
        requires :id, type: Integer
        requires :credentials, type: Hash, desc: "Nuevas credenciales"
        optional :test_connection_after, type: Boolean, default: false,
                 desc: "Probar conexión después de actualizar"
      end
      put ":id/credentials" do
        config = TenantIntegrationConfiguration.find(params[:id])

        # Si está activa, desactivar temporalmente
        was_active = config.is_active
        config.update!(is_active: false) if was_active

        # Actualizar credenciales
        if config.update(credentials: params[:credentials])
          # Limpiar estado de última sincronización
          config.update(last_sync_status: nil, last_sync_error: nil)

          # Probar conexión si se solicita
          if params[:test_connection_after]
            test_result = Integrations::TenantConfigurations::TestConnectionService.new(
              config.integration_provider.id,
              params[:credentials]
            ).call

            unless test_result.success?
              error!({
                error: "connection_test_failed",
                message: "Credenciales actualizadas pero el test de conexión falló: #{test_result.errors.join(', ')}",
                config: Entities::TenantIntegrationConfigurationEntity.represent(
                  config, include_computed: true
                )
              }, 422)
            end
          end

          # Re-activar si estaba activa
          config.update!(is_active: true) if was_active

          present config,
                  with: Entities::TenantIntegrationConfigurationEntity,
                  include_computed: true,
                  include_provider: true
        else
          error!({
            error: "validation_error",
            message: config.errors.full_messages.join(", ")
          }, 422)
        end
      end

      # Bloque 2: Actualizar Features
      desc "Actualizar features habilitadas"
      params do
        requires :id, type: Integer
        requires :enabled_features, type: Array[String], desc: "Lista de feature keys a habilitar"
      end
      put ":id/features" do
        config = TenantIntegrationConfiguration.find(params[:id])

        # Validar que todas las features existan
        available_features = config.integration_provider.integration_features.active.pluck(:feature_key)
        invalid_features = params[:enabled_features] - available_features

        if invalid_features.any?
          error!({
            error: "invalid_features",
            message: "Features no disponibles: #{invalid_features.join(', ')}",
            available_features: available_features
          }, 422)
        end

        if config.update(enabled_features: params[:enabled_features])
          present config,
                  with: Entities::TenantIntegrationConfigurationEntity,
                  include_computed: true,
                  include_features: true
        else
          error!({
            error: "validation_error",
            message: config.errors.full_messages.join(", ")
          }, 422)
        end
      end

      # Bloque 3: Actualizar Programación
      desc "Actualizar configuración de programación de sincronización"
      params do
        requires :id, type: Integer
        requires :sync_frequency, type: String, values: %w[daily weekly monthly]
        requires :sync_hour, type: Integer, values: 0..23
        optional :sync_day_of_week, type: Integer, values: 0..6
        optional :sync_day_of_month, type: String, values: %w[start end]
      end
      put ":id/schedule" do
        config = TenantIntegrationConfiguration.find(params[:id])

        update_params = {
          sync_frequency: params[:sync_frequency],
          sync_hour: params[:sync_hour],
          sync_day_of_week: params[:sync_day_of_week],
          sync_day_of_month: params[:sync_day_of_month]
        }

        if config.update(update_params)
          present config,
                  with: Entities::TenantIntegrationConfigurationEntity,
                  include_computed: true
        else
          error!({
            error: "validation_error",
            message: config.errors.full_messages.join(", ")
          }, 422)
        end
      end

      # Actualización completa (mantener por compatibilidad)
      desc "Actualizar configuración completa"
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
        config = TenantIntegrationConfiguration.find(params[:id])

        result = Integrations::TenantConfigurations::UpdateService.new(
          config,
          declared(params, include_missing: false)
        ).call

        if result.success?
          present result.data,
                  with: Entities::TenantIntegrationConfigurationEntity,
                  include_computed: true,
                  include_provider: true
        else
          error!({
            error: "validation_error",
            message: result.errors.join(", ")
          }, 422)
        end
      end

      desc "Activar configuración"
      params do
        requires :id, type: Integer
      end
      post ":id/activate" do
        config = TenantIntegrationConfiguration.find(params[:id])

        result = Integrations::TenantConfigurations::ActivateService.new(config).call

        if result.success?
          present result.data,
                  with: Entities::TenantIntegrationConfigurationEntity,
                  include_computed: true
        else
          error!({
            error: "activation_error",
            message: result.errors.join(", ")
          }, 422)
        end
      end

      desc "Desactivar configuración"
      params do
        requires :id, type: Integer
      end
      post ":id/deactivate" do
        config = TenantIntegrationConfiguration.find(params[:id])

        result = Integrations::TenantConfigurations::DeactivateService.new(config).call

        if result.success?
          present result.data,
                  with: Entities::TenantIntegrationConfigurationEntity,
                  include_computed: true
        else
          error!({
            error: "deactivation_error",
            message: result.errors.join(", ")
          }, 422)
        end
      end

       desc "Re-probar conexión de una configuración existente"
      params do
        requires :id, type: Integer
        optional :use_new_credentials, type: Hash,
                 desc: "Probar con credenciales diferentes sin guardarlas"
      end
      post ":id/test_connection" do
        config = TenantIntegrationConfiguration.find(params[:id])

        # Usar credenciales de prueba o las actuales
        credentials_to_test = params[:use_new_credentials] || config.credentials

        result = Integrations::TenantConfigurations::TestConnectionService.new(
          config.integration_provider.id,
          credentials_to_test
        ).call

        if result.success?
          present result.data, with: Entities::ConnectionTestResultEntity
        else
          error!({
            error: "connection_failed",
            message: result.errors.join(", ")
          }, 422)
        end
      end

      desc "Ejecutar sincronización manual de una feature específica"
      params do
        requires :id, type: Integer
        requires :feature_key, type: String,
                 values: %w[fuel battery trips real_time_location odometer diagnostics],
                 desc: "Feature a sincronizar"
      end
      post ":id/sync" do
        config = TenantIntegrationConfiguration.find(params[:id])

        # Verificar que esté activa
        unless config.is_active
          error!({
            error: "inactive_configuration",
            message: "La configuración debe estar activa para sincronizar"
          }, 422)
        end

        # Verificar que la feature esté habilitada
        unless config.feature_enabled?(params[:feature_key])
          error!({
            error: "feature_not_enabled",
            message: "La feature '#{params[:feature_key]}' no está habilitada en esta configuración",
            enabled_features: config.enabled_features
          }, 422)
        end

        # Ejecutar sincronización
        result = Integrations::Sync::SyncExecutionService.new(
          config,
          params[:feature_key],
          manual: true
        ).call

        if result.success?
          present result.data, with: Entities::SyncResultEntity
        else
          error!({
            error: "sync_error",
            message: result.errors.join(", "),
            execution_id: result.data&.dig(:execution_id)
          }, 422)
        end
      end

      # Sincronizar todas las features habilitadas
      desc "Ejecutar sincronización de TODAS las features habilitadas"
      params do
        requires :id, type: Integer
      end
      post ":id/sync_all" do
        config = TenantIntegrationConfiguration.find(params[:id])

        unless config.is_active
          error!({
            error: "inactive_configuration",
            message: "La configuración debe estar activa para sincronizar"
          }, 422)
        end

        if config.enabled_features.empty?
          error!({
            error: "no_features_enabled",
            message: "No hay features habilitadas para sincronizar"
          }, 422)
        end

        # Ejecutar sync para cada feature
        results = []
        config.enabled_features.each do |feature_key|
          result = Integrations::Sync::SyncExecutionService.new(
            config,
            feature_key,
            manual: true
          ).call

          results << {
            feature_key: feature_key,
            success: result.success?,
            execution_id: result.data&.dig(:execution_id),
            message: result.success? ? result.message : result.errors.join(", ")
          }
        end

        {
          total_features: results.count,
          successful: results.count { |r| r[:success] },
          failed: results.count { |r| !r[:success] },
          results: results
        }
      end

      desc "Eliminar configuración de integración"
      params do
        requires :id, type: Integer
      end
      delete ":id" do
        config = TenantIntegrationConfiguration.find(params[:id])

        result = Integrations::TenantConfigurations::DestroyService.new(config).call

        if result.success?
          { success: true, message: result.message }
        else
          error!({
            error: "deletion_error",
            message: result.errors.join(", ")
          }, 422)
        end
      end

      desc "Obtener estadísticas de sincronización de una configuración"
      params do
        requires :id, type: Integer
      end
      get ":id/statistics" do
        config = TenantIntegrationConfiguration.find(params[:id])

        {
          configuration_id: config.id,
          provider: {
            name: config.integration_provider.name,
            slug: config.integration_provider.slug
          },
          sync_statistics: config.sync_statistics,
          enabled_features: config.enabled_features,
          is_active: config.is_active,
          last_sync_at: config.last_sync_at,
          last_sync_status: config.last_sync_status,
          sync_schedule: config.sync_schedule_description
        }
      end

      desc "Obtener historial de sincronizaciones"
      params do
        requires :id, type: Integer
        optional :feature_key, type: String
        optional :status, type: String, values: %w[running completed failed]
        optional :limit, type: Integer, default: 50
      end
      get ":id/sync_history" do
        config = TenantIntegrationConfiguration.find(params[:id])

        executions = config.integration_sync_executions.recent
        executions = executions.by_feature(params[:feature_key]) if params[:feature_key]
        executions = executions.where(status: params[:status]) if params[:status]
        executions = executions.limit(params[:limit])

        present executions, with: Entities::IntegrationSyncExecutionSummaryEntity
      end

      desc "Obtener opciones disponibles para programación"
      get "schedule_options" do
        present({}, with: Entities::SyncScheduleOptionsEntity)
      end
    end
  end
end
