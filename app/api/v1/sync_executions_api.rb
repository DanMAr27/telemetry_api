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

      desc "Estadísticas globales consolidadas de sincronizaciones"
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

      route_param :execution_id do
        desc "Obtener detalle de una ejecución"
        get do
          execution = IntegrationSyncExecution.find(params[:execution_id])
          present execution, with: Entities::IntegrationSyncExecutionEntity
        end

        desc "Reintentar ejecución fallida"
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

        desc "Raw data de esta ejecución"
        params do
          optional :status, type: String
          optional :limit, type: Integer, default: 100
        end
        get "raw-data" do
          execution = IntegrationSyncExecution.find(params[:execution_id])
          raw_data = execution.integration_raw_data

          raw_data = raw_data.where(processing_status: params[:status]) if params[:status]
          raw_data = raw_data.limit(params[:limit])

          present raw_data, with: Entities::IntegrationRawDataEntity
        end

        desc "Errores de normalización"
        get "errors" do
          execution = IntegrationSyncExecution.find(params[:execution_id])
          errors = execution.integration_raw_data.failed

          present errors, with: Entities::IntegrationRawDataEntity
        end

        desc "Reprocesar registros fallidos de esta ejecución"
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
