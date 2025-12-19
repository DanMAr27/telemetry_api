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
            desc "Ejecutar sincronización manual de una feature" do
              detail "Obtiene datos del proveedor de telemetría y los normaliza"
              success Entities::SyncResultEntity
              failure [ [ 401, "No autorizado" ], [ 422, "Error de validación" ] ]
            end

            params do
              requires :feature_key,
                       type: String,
                       values: %w[fuel battery trips real_time_location],
                       desc: "Feature a sincronizar",
                       documentation: {
                         example: "fuel"
                       }
            end

            post "sync" do
              # Buscar configuración
              config = current_tenant
                .tenant_integration_configurations
                .find(params[:config_id])

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
                  message: "La feature '#{params[:feature_key]}' no está habilitada",
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
                # Respuesta exitosa
                present result.data, with: Entities::SyncResultEntity
              else
                # Error en sincronización
                error!({
                  error: "sync_error",
                  message: result.errors.join(", "),
                  execution_id: result.data&.dig(:execution_id)
                }, 422)
              end
            end

            desc "Sincronizar todas las features habilitadas" do
              detail "Ejecuta sincronización para cada feature activa en secuencia"
            end

            post "sync_all" do
              config = current_tenant
                .tenant_integration_configurations
                .find(params[:config_id])

              unless config.is_active
                error!({
                  error: "inactive_configuration",
                  message: "La configuración debe estar activa"
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
                  message: result.success? ? result.message : result.errors.join(", "),
                  data: result.success? ? result.data : nil
                }
              end

              # Retornar resumen
              {
                total_features: results.count,
                successful: results.count { |r| r[:success] },
                failed: results.count { |r| !r[:success] },
                results: results
              }
            end

            desc "Listar historial de sincronizaciones" do
              detail "Muestra las ejecuciones pasadas con sus estadísticas"
            end

            params do
              optional :feature_key,
                       type: String,
                       desc: "Filtrar por feature"
              optional :status,
                       type: String,
                       values: %w[running completed failed],
                       desc: "Filtrar por estado"
              optional :limit,
                       type: Integer,
                       default: 50,
                       values: 1..100,
                       desc: "Número de registros"
            end

            get "sync_executions" do
              config = current_tenant
                .tenant_integration_configurations
                .find(params[:config_id])

              # Construir query
              executions = config.integration_sync_executions.recent

              # Aplicar filtros
              if params[:feature_key]
                executions = executions.by_feature(params[:feature_key])
              end

              if params[:status]
                executions = executions.where(status: params[:status])
              end

              executions = executions.limit(params[:limit])

              # Retornar
              present executions,
                      with: Entities::IntegrationSyncExecutionSummaryEntity
            end

            desc "Ver detalle de una ejecución de sincronización"

            params do
              requires :execution_id, type: Integer
            end

            get "sync_executions/:execution_id" do
              config = current_tenant
                .tenant_integration_configurations
                .find(params[:config_id])

              execution = config
                .integration_sync_executions
                .find(params[:execution_id])

              present execution,
                      with: Entities::IntegrationSyncExecutionEntity,
                      include_computed: true
            end

            desc "Obtener estadísticas de sincronización"

            get "sync_statistics" do
              config = current_tenant
                .tenant_integration_configurations
                .find(params[:config_id])

              stats = {
                # Estadísticas de ejecuciones
                total_executions: config.integration_sync_executions.count,
                completed: config.integration_sync_executions.completed.count,
                failed: config.integration_sync_executions.failed.count,
                running: config.integration_sync_executions.running.count,

                # Estadísticas de datos RAW
                total_raw_records: config.integration_raw_data.count,
                pending_records: config.integration_raw_data.pending.count,
                normalized_records: config.integration_raw_data.normalized.count,
                failed_records: config.integration_raw_data.failed.count,
                duplicate_records: config.integration_raw_data.duplicate.count,

                # Timestamps
                last_sync_at: config.last_sync_at,
                last_sync_status: config.last_sync_status,

                # Agrupaciones
                by_feature: config.integration_sync_executions
                  .group(:feature_key).count,
                by_status: config.integration_sync_executions
                  .group(:status).count
              }

              present stats, with: Entities::SyncStatisticsEntity
            end
          end
        end
      end
    end
  end
end
