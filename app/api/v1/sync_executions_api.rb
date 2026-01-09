# app/api/v1/sync_executions_api.rb
module V1
  class SyncExecutionsApi < Grape::API
    resource :sync_executions do
      desc "Listar todas las ejecuciones de sincronización" do
        detail "Retorna ejecuciones con filtros avanzados"
      end
      params do
        optional :tenant_id, type: Integer
        optional :integration_id, type: Integer
        optional :feature_key, type: String
        optional :status, type: String, values: %w[running completed failed]
        optional :from_date, type: Date
        optional :to_date, type: Date
        optional :page, type: Integer, default: 1
        optional :per_page, type: Integer, default: 50
      end
      get do
        executions = IntegrationSyncExecution.includes(:tenant_integration_configuration)

        # Aplicar filtros
        if params[:tenant_id]
          executions = executions.joins(:tenant_integration_configuration)
            .where(tenant_integration_configurations: { tenant_id: params[:tenant_id] })
        end

        executions = executions.where(tenant_integration_configuration_id: params[:integration_id]) if params[:integration_id]
        executions = executions.where(feature_key: params[:feature_key]) if params[:feature_key]
        executions = executions.where(status: params[:status]) if params[:status]

        if params[:from_date] && params[:to_date]
          executions = executions.where(started_at: params[:from_date]..params[:to_date])
        end

        total = executions.count
        executions = executions.order(started_at: :desc)
          .offset((params[:page] - 1) * params[:per_page])
          .limit(params[:per_page])

        {
          executions: Entities::IntegrationSyncExecutionSummaryEntity.represent(executions),
          pagination: {
            current_page: params[:page],
            per_page: params[:per_page],
            total_items: total,
            total_pages: (total.to_f / params[:per_page]).ceil
          }
        }
      end

      desc "Estadísticas globales consolidadas de sincronizaciones" do
        detail "Estadísticas globales de sincronizaciones"
      end
      params do
        optional :tenant_id, type: Integer
        optional :integration_id, type: Integer
        optional :feature_key, type: String
        optional :from_date, type: Date
        optional :to_date, type: Date
        optional :group_by, type: String, values: %w[day week month feature]
      end
      get "statistics" do
        result = Integrations::Sync::GlobalStatisticsService.new(
          tenant_id: params[:tenant_id],
          integration_id: params[:integration_id],
          feature_key: params[:feature_key],
          from_date: params[:from_date] || 30.days.ago,
          to_date: params[:to_date] || Date.current,
          group_by: params[:group_by]
        ).call

        present result.data
      end

      desc "Sincronizar una feature específica" do
        detail "Ejecuta sincronización manual para una feature. " \
                "Crea una nueva ejecución que puede consultarse en /sync_executions"
        success Entities::SyncResultEntity
      end
      params do
        requires :integration_id, type: Integer, desc: "ID de la configuración de integración"
        requires :feature_key,
                  type: String,
                  values: %w[fuel battery trips real_time_location odometer diagnostics],
                  desc: "Feature a sincronizar"
      end
      post "sync-feature" do
        config = TenantIntegrationConfiguration.find(params[:integration_id])

        unless config.is_active
          error!({
            error: "inactive_configuration",
            message: "La configuración debe estar activa para sincronizar"
          }, 422)
        end

        unless config.feature_enabled?(params[:feature_key])
          error!({
            error: "feature_not_enabled",
            message: "La feature '#{params[:feature_key]}' no está habilitada",
            enabled_features: config.enabled_features,
            hint: "Habilita esta feature primero usando PUT /integrations/#{config.id}/features"
          }, 422)
        end

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
      rescue ActiveRecord::RecordNotFound
        error!({
          error: "not_found",
          message: "Configuración de integración no encontrada"
        }, 404)
      end

      desc "Sincronizar todas las features habilitadas" do
        detail "Ejecuta sincronización para cada feature activa en secuencia. " \
                "Cada ejecución puede consultarse en /sync_executions"
      end
      params do
        requires :integration_id, type: Integer,
                 desc: "ID de la configuración de integración"
      end
      post "sync-all" do
        config = TenantIntegrationConfiguration.find(params[:integration_id])

        unless config.is_active
          error!({
            error: "inactive_configuration",
            message: "La configuración debe estar activa para sincronizar"
          }, 422)
        end

        if config.enabled_features.empty?
          error!({
            error: "no_features_enabled",
            message: "No hay features habilitadas para sincronizar",
            hint: "Habilita features usando PUT /integrations/#{config.id}/features"
          }, 422)
        end

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

        {
          integration_id: config.id,
          provider_name: config.integration_provider.name,
          total_features: results.count,
          successful: results.count { |r| r[:success] },
          failed: results.count { |r| !r[:success] },
          results: results,
          hint: "Consulta el detalle de cada ejecución en GET /sync_executions/:execution_id"
        }
      rescue ActiveRecord::RecordNotFound
        error!({
          error: "not_found",
          message: "Configuración de integración no encontrada"
        }, 404)
      end

      route_param :execution_id do
        desc "Obtener detalle de una ejecución" do
          detail "Detalle ejecución"
        end
        get do
          execution = IntegrationSyncExecution.find(params[:execution_id])
          present execution, with: Entities::IntegrationSyncExecutionEntity
        end

        desc "Reintentar ejecución fallida" do
          detail "Re-ejecutar sync (fetch + normalize)"
        end
        post "retry" do
          execution = IntegrationSyncExecution.find(params[:execution_id])

          unless execution.failed?
            error!({ error: "Solo se pueden reintentar ejecuciones fallidas" }, 422)
          end

          result = Integrations::Sync::SyncExecutionService.new(
            execution.tenant_integration_configuration,
            execution.feature_key,
            manual: true
          ).call

          present result.data, with: Entities::SyncResultEntity
        end

        desc "Reprocesar registros fallidos de esta ejecución" do
          detail "reintenta TODO lo que falló en esa ejecución (bulk)"
        end
        post "reprocess" do
          execution = IntegrationSyncExecution.find(params[:execution_id])

          result = Integrations::Normalizers::BatchRetryService.new(
            execution.integration_raw_data.failed,
            execution.tenant_integration_configuration
          ).call

          present result.data
        end
      end
    end
  end
end
