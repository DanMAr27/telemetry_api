# app/api/v1/sync_executions.rb
module V1
  class SyncExecutionsApi < Grape::API
    helpers do
      def current_tenant
        @current_tenant ||= Tenant.find(params[:tenant_id])
      end
    end

    resource :tenants do
      route_param :tenant_id do
        resource :integration_configurations do
          route_param :config_id do
            # ==========================================================
            # POST /api/v1/tenants/:tenant_id/integration_configurations/:config_id/sync
            # Ejecutar sincronización MANUALMENTE
            # ==========================================================
            desc "Ejecutar sincronización manual"
            params do
              requires :feature_key, type: String,
                        values: %w[fuel battery trips real_time_location],
                        desc: "Feature a sincronizar"
            end
            post "sync" do
              config = current_tenant.tenant_integration_configurations.find(params[:config_id])

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

            # ==========================================================
            # GET /api/v1/tenants/:tenant_id/integration_configurations/:config_id/sync_executions
            # Listar ejecuciones de sincronización
            # ==========================================================
            desc "Listar ejecuciones de sincronización"
            params do
              optional :feature_key, type: String
              optional :status, type: String, values: %w[running completed failed]
              optional :limit, type: Integer, default: 50
            end
            get "sync_executions" do
              config = current_tenant.tenant_integration_configurations.find(params[:config_id])

              executions = config.integration_sync_executions.recent
              executions = executions.by_feature(params[:feature_key]) if params[:feature_key]
              executions = executions.where(status: params[:status]) if params[:status]
              executions = executions.limit(params[:limit])

              present executions, with: Entities::IntegrationSyncExecutionSummaryEntity
            end

            # ==========================================================
            # GET /api/v1/tenants/:tenant_id/sync_executions/:id
            # Ver detalle de una ejecución
            # ==========================================================
            desc "Ver detalle de una ejecución"
            params do
              requires :execution_id, type: Integer
            end
            get "sync_executions/:execution_id" do
              config = current_tenant.tenant_integration_configurations.find(params[:config_id])
              execution = config.integration_sync_executions.find(params[:execution_id])

              present execution,
                      with: Entities::IntegrationSyncExecutionEntity,
                      include_computed: true
            end

            # ==========================================================
            # GET /api/v1/tenants/:tenant_id/integration_configurations/:config_id/raw_data
            # Ver datos RAW (para debugging)
            # ==========================================================
            desc "Ver datos RAW"
            params do
              optional :status, type: String, values: %w[pending normalized failed duplicate]
              optional :limit, type: Integer, default: 100
            end
            get "raw_data" do
              config = current_tenant.tenant_integration_configurations.find(params[:config_id])

              raw_data = config.integration_raw_data.recent
              raw_data = raw_data.where(processing_status: params[:status]) if params[:status]
              raw_data = raw_data.limit(params[:limit])

              present raw_data, with: Entities::IntegrationRawDataEntity
            end

            # ==========================================================
            # GET /api/v1/tenants/:tenant_id/integration_configurations/:config_id/sync_statistics
            # Estadísticas de sincronización
            # ==========================================================
            desc "Estadísticas de sincronización"
            get "sync_statistics" do
              config = current_tenant.tenant_integration_configurations.find(params[:config_id])

              stats = {
                total_executions: config.integration_sync_executions.count,
                completed_executions: config.integration_sync_executions.completed.count,
                failed_executions: config.integration_sync_executions.failed.count,
                running_executions: config.integration_sync_executions.running.count,
                total_raw_records: config.integration_raw_data.count,
                pending_records: config.integration_raw_data.pending.count,
                normalized_records: config.integration_raw_data.normalized.count,
                failed_records: config.integration_raw_data.failed.count,
                duplicate_records: config.integration_raw_data.duplicate.count,
                last_sync_at: config.last_sync_at,
                next_sync_at: config.calculate_next_sync_at,
                by_feature: config.integration_sync_executions.group(:feature_key).count,
                by_status: config.integration_sync_executions.group(:status).count
              }

              present stats, with: Entities::SyncStatisticsEntity
            end
          end
        end
      end
    end
  end
end
