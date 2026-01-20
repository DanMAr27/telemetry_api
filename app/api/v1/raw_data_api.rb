# app/api/v1/raw_data_api.rb
module V1
  class RawDataApi < Grape::API
    resource :raw_data do
      desc "Listar registros de raw data con filtros avanzados" do
        detail "Retorna lista paginada de registros RAW con múltiples filtros"
        success Entities::IntegrationRawDataEntity
      end
      params do
        optional :tenant_id, type: Integer, desc: "Filtrar por tenant"
        optional :integration_id, type: Integer, desc: "Filtrar por configuración de integración"
        optional :feature_key, type: String, desc: "Filtrar por feature (fuel, battery, trips)"
        optional :provider_slug, type: String, desc: "Filtrar por proveedor"
        optional :external_id, type: String, desc: "Filtrar por ID externo"
        optional :status, type: String,
                 values: %w[pending normalized failed duplicate skipped],
                 desc: "Filtrar por estado de procesamiento"
        optional :status_in, type: Array[String], desc: "Filtrar por múltiples estados"
        optional :from_date, type: Date, desc: "Fecha desde"
        optional :to_date, type: Date, desc: "Fecha hasta"
        optional :created_after, type: DateTime, desc: "Creados después de"
        optional :created_before, type: DateTime, desc: "Creados antes de"
        optional :sync_execution_id, type: Integer, desc: "Filtrar por ejecución de sync"
        optional :only_latest_sync, type: Boolean, default: false,
                 desc: "Solo registros de la última sincronización"
        optional :has_error, type: Boolean, desc: "Filtrar por presencia de error"
        optional :error_contains, type: String, desc: "Buscar en mensaje de error"
        optional :retriable, type: Boolean, desc: "Solo errores recuperables"
        optional :sort_by, type: String,
                 values: %w[created_at normalized_at external_id id],
                 default: "created_at",
                 desc: "Campo para ordenar"
        optional :sort_order, type: String, values: %w[asc desc], default: "desc",
                 desc: "Dirección del ordenamiento"
        optional :page, type: Integer, default: 1, desc: "Número de página"
        optional :per_page, type: Integer, default: 50, values: 1..500,
                 desc: "Registros por página"
        optional :include_raw_data, type: Boolean, default: false,
                 desc: "Incluir JSON completo del proveedor"
        optional :include_execution, type: Boolean, default: false,
                 desc: "Incluir datos de la ejecución de sync"
        optional :include_normalized, type: Boolean, default: false,
                 desc: "Incluir registro normalizado relacionado"
        optional :include_metadata, type: Boolean, default: true,
                 desc: "Incluir metadata adicional"
      end
      get do
        result = Integrations::RawData::ListService.new(
          filters: declared(params, include_missing: false)
        ).call

        if result.success?
          {
            raw_data: Entities::IntegrationRawDataEntity.represent(
              result.data[:raw_data],
              include_raw_data: params[:include_raw_data],
              include_execution: params[:include_execution],
              include_normalized: params[:include_normalized],
              include_actions: true
            ),
            summary: result.data[:summary],
            pagination: result.data[:pagination]
          }
        else
          error!({
            error: "list_failed",
            message: result.errors.join(", ")
          }, 500)
        end
      end

      desc "Obtener detalle completo de un registro" do
        detail "Retorna información detallada de un registro RAW específico"
        success Entities::IntegrationRawDataDetailEntity
      end
      params do
        requires :id, type: Integer, desc: "ID del registro"
      end
      get ":id" do
        result = Integrations::RawData::GetDetailService.new(id: params[:id]).call

        if result.success?
          present result.data, with: Entities::IntegrationRawDataDetailEntity
        else
          error!({
            error: "not_found",
            message: result.errors.join(", ")
          }, 404)
        end
      end

      desc "Reintentar normalización de uno o más registros" do
        detail "Vuelve a intentar normalizar registros que fallaron previamente"
      end
      params do
        requires :ids, type: Array[Integer],
                 desc: "IDs de registros a reintentar (mínimo 1, máximo 1000)"
        optional :notes, type: String, desc: "Notas adicionales sobre el reintento"
      end
      post "retry" do
        result = Integrations::RawData::RetryService.new(
          ids: params[:ids],
          notes: params[:notes]
        ).call

        if result.success?
          {
            success: true,
            action: "retry",
            summary: {
              total: result.data[:total],
              successful: result.data[:successful],
              failed: result.data[:failed]
            },
            results: result.data[:results],
            duration_seconds: result.data[:duration_seconds],
            message: result.message
          }
        else
          error!({
            error: "retry_failed",
            message: result.errors.join(", ")
          }, 422)
        end
      end

      desc "Omitir uno o más registros" do
        detail "Marca registros como omitidos (skipped) con un motivo específico"
      end
      params do
        requires :ids, type: Array[Integer],
                 desc: "IDs de registros a omitir"
        requires :reason, type: String,
                 desc: "Motivo obligatorio de la omisión"
        optional :notes, type: String,
                 desc: "Notas adicionales"
      end
      post "skip" do
        result = Integrations::RawData::SkipService.new(
          ids: params[:ids],
          reason: params[:reason],
          notes: params[:notes]
        ).call

        if result.success?
          {
            success: true,
            action: "skip",
            summary: {
              total: result.data[:total],
              successful: result.data[:successful],
              failed: result.data[:failed]
            },
            results: result.data[:results],
            duration_seconds: result.data[:duration_seconds],
            message: result.message
          }
        else
          error!({
            error: "skip_failed",
            message: result.errors.join(", ")
          }, 422)
        end
      end

      desc "Resetear uno o más registros a estado pending" do
        detail "Devuelve registros al estado pending para que sean reprocesados"
      end
      params do
        requires :ids, type: Array[Integer],
                 desc: "IDs de registros a resetear"
        optional :notes, type: String,
                 desc: "Notas sobre el motivo del reset"
      end
      post "reset" do
        result = Integrations::RawData::ResetService.new(
          ids: params[:ids],
          notes: params[:notes]
        ).call

        if result.success?
          {
            success: true,
            action: "reset",
            summary: {
              total: result.data[:total],
              successful: result.data[:successful],
              failed: result.data[:failed]
            },
            results: result.data[:results],
            duration_seconds: result.data[:duration_seconds],
            message: result.message
          }
        else
          error!({
            error: "reset_failed",
            message: result.errors.join(", ")
          }, 422)
        end
      end

      desc "Soft delete raw data record" do
        detail "Soft deletes a raw data record with validations and audit trail"
      end
      params do
        requires :id, type: Integer, desc: "Raw data ID"
        optional :force, type: Boolean, default: false, desc: "Force deletion ignoring warnings"
      end
      delete ":id" do
        raw_data = IntegrationRawData.find(params[:id])

        coordinator = SoftDelete::DeletionCoordinator.new(
          raw_data,
          force: params[:force]
        )

        result = coordinator.call

        if result[:success]
          {
            success: true,
            message: result[:message],
            raw_data_id: params[:id],
            impact: {
              cascade_count: result[:cascade_count],
              nullify_count: result[:nullify_count]
            },
            audit_log_id: result[:audit_log]&.id
          }
        else
          error!({
            error: "deletion_failed",
            message: result[:message],
            errors: result[:errors],
            warnings: result[:warnings],
            requires_force: result[:requires_force]
          }, 422)
        end
      rescue ActiveRecord::RecordNotFound
        error!({ error: "not_found", message: "Raw data not found" }, 404)
      end

      desc "Preview deletion impact for raw data" do
        detail "Analyzes the impact of deleting raw data without actually deleting it"
      end
      params do
        requires :id, type: Integer, desc: "Raw data ID"
      end
      post ":id/deletion-preview" do
        raw_data = IntegrationRawData.find(params[:id])
        impact = SoftDelete::ImpactAnalyzer.new(raw_data).analyze

        {
          raw_data_id: params[:id],
          can_delete: impact[:can_delete],
          recommendation: impact[:recommendation],
          blockers: impact[:blockers],
          warnings: impact[:warnings],
          impact: {
            will_cascade: impact[:will_cascade],
            will_nullify: impact[:will_nullify],
            total_affected: impact[:total_affected]
          },
          estimated_time: impact[:estimated_time]
        }
      rescue ActiveRecord::RecordNotFound
        error!({ error: "not_found", message: "Raw data not found" }, 404)
      end
    end
  end
end
