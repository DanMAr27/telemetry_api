# app/api/v1/soft_delete_api.rb
module V1
  class SoftDeleteApi < Grape::API
    helpers do
      def find_record_by_type(model_type, id)
        model_class = case model_type
        when "integration_raw_data"
          IntegrationRawData
        when "financial_transaction"
          FinancialTransaction
        when "vehicle_refueling"
          VehicleRefueling
        when "vehicle_electric_charge"
          VehicleElectricCharge
        when "vehicle"
          Vehicle
        else
          error!({ error: "invalid_model", message: "Tipo de modelo no soportado" }, 400)
        end

        model_class.find(id)
      rescue ActiveRecord::RecordNotFound
        error!({ error: "not_found", message: "Registro no encontrado" }, 404)
      end
    end

    resource :soft_delete do
      desc "Analizar impacto de borrado" do
        detail "Retorna el análisis de impacto sin ejecutar el borrado"
      end
      params do
        requires :model_type, type: String,
                 values: %w[integration_raw_data financial_transaction vehicle_refueling vehicle_electric_charge vehicle],
                 desc: "Tipo de modelo a analizar"
        requires :id, type: Integer, desc: "ID del registro"
      end
      post "preview" do
        record = find_record_by_type(params[:model_type], params[:id])

        impact = SoftDelete::ImpactAnalyzer.new(record).analyze

        {
          model_type: params[:model_type],
          record_id: params[:id],
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
      end

      desc "Ejecutar borrado soft delete" do
        detail "Ejecuta el borrado con validaciones y auditoría"
      end
      params do
        requires :model_type, type: String,
                 values: %w[integration_raw_data financial_transaction vehicle_refueling vehicle_electric_charge vehicle],
                 desc: "Tipo de modelo a borrar"
        requires :id, type: Integer, desc: "ID del registro"
        optional :force, type: Boolean, default: false,
                 desc: "Forzar borrado ignorando warnings (no blockers)"
        optional :cascade_options, type: Hash, default: {},
                 desc: "Decisiones para cascadas opcionales"
      end
      post "delete" do
        record = find_record_by_type(params[:model_type], params[:id])

        coordinator = SoftDelete::DeletionCoordinator.new(
          record,
          force: params[:force],
          cascade_options: params[:cascade_options]
          # user: current_user # No hay gestión de usuarios
        )

        result = coordinator.call

        if result[:success]
          {
            success: true,
            message: result[:message],
            record_id: params[:id],
            model_type: params[:model_type],
            impact: {
              cascade_count: result[:cascade_count],
              nullify_count: result[:nullify_count]
            },
            audit_log_id: result[:audit_log]&.id,
            warnings: result[:warnings]
          }
        else
          error!({
            error: "deletion_failed",
            message: result[:message],
            errors: result[:errors],
            warnings: result[:warnings],
            requires_force: result[:requires_force],
            optional_cascades: result[:optional_cascades]
          }, 422)
        end
      end

      desc "Listar logs de auditoría" do
        detail "Retorna el historial de borrados"
      end
      params do
        optional :model_type, type: String,
                 values: %w[integration_raw_data financial_transaction vehicle_refueling vehicle_electric_charge vehicle],
                 desc: "Filtrar por tipo de modelo"
        optional :from_date, type: DateTime, desc: "Fecha desde"
        optional :to_date, type: DateTime, desc: "Fecha hasta"
        optional :massive_only, type: Boolean, default: false,
                 desc: "Solo operaciones masivas (>10 registros afectados)"
        optional :page, type: Integer, default: 1
        optional :per_page, type: Integer, default: 50, values: 1..100
      end
      get "audit_logs" do
        logs = SoftDeleteAuditLog.recent

        if params[:model_type]
          # Manejar el caso especial de integration_raw_data
          model_name = if params[:model_type] == "integration_raw_data"
                         "IntegrationRawData"
          else
                         params[:model_type].classify
          end
          logs = logs.where(record_type: model_name)
        end
        logs = logs.between_dates(params[:from_date], params[:to_date]) if params[:from_date] && params[:to_date]
        logs = logs.massive_operations if params[:massive_only]

        total = logs.count

        logs = logs
          .offset((params[:page] - 1) * params[:per_page])
          .limit(params[:per_page])

        {
          audit_logs: logs.map do |log|
            {
              id: log.id,
              record_type: log.record_type,
              record_id: log.record_id,
              action: log.action,
              performed_at: log.performed_at,
              performed_by: log.performed_by_description,
              impact: {
                cascade_count: log.cascade_count,
                nullify_count: log.nullify_count,
                total: log.total_impact,
                description: log.impact_description
              },
              context: log.context,
              massive_operation: log.massive_operation?
            }
          end,
          pagination: {
            current_page: params[:page],
            per_page: params[:per_page],
            total_items: total,
            total_pages: (total.to_f / params[:per_page]).ceil
          }
        }
      end

      desc "Obtener estadísticas de borrados" do
        detail "Retorna estadísticas generales de auditoría"
      end
      params do
        optional :days, type: Integer, default: 30, desc: "Últimos N días"
      end
      get "stats" do
        logs = SoftDeleteAuditLog.last_days(params[:days])

        {
          period: {
            days: params[:days],
            from: params[:days].days.ago,
            to: Time.current
          },
          total_deletions: logs.count,
          by_model: logs.group(:record_type).count,
          total_cascade_impact: logs.sum(:cascade_count),
          total_nullify_impact: logs.sum(:nullify_count),
          massive_operations: logs.massive_operations.count,
          top_deleted_models: SoftDeleteAuditLog.top_deleted_models(5),
          recent_high_impact: logs.where("cascade_count + nullify_count >= ?", 10).count
        }
      end

      desc "Obtener detalle de un log de auditoría" do
        detail "Retorna información completa de un borrado específico"
      end
      params do
        requires :log_id, type: Integer, desc: "ID del log de auditoría"
      end
      get "audit_logs/:log_id" do
        log = SoftDeleteAuditLog.find(params[:log_id])

        {
          id: log.id,
          record_type: log.record_type,
          record_id: log.record_id,
          action: log.action,
          action_description: log.action_description,
          performed_at: log.performed_at,
          performed_by: log.performed_by_description,
          impact: {
            cascade_count: log.cascade_count,
            nullify_count: log.nullify_count,
            total: log.total_impact,
            description: log.impact_description,
            has_cascade: log.has_cascade_impact?,
            has_nullify: log.has_nullify_impact?
          },
          context: log.context,
          massive_operation: log.massive_operation?
        }
      rescue ActiveRecord::RecordNotFound
        error!({ error: "not_found", message: "Log de auditoría no encontrado" }, 404)
      end
    end
  end
end
