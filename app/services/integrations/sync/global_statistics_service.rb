# app/services/integrations/sync/global_statistics_service.rb
module Integrations
  module Sync
    class GlobalStatisticsService
      def initialize(filters = {})
        @tenant_id = filters[:tenant_id]
        @integration_id = filters[:integration_id]
        @feature_key = filters[:feature_key]

        # Asegurar que siempre sean Date, no Time/DateTime
        @from_date = parse_date(filters[:from_date] || 30.days.ago)
        @to_date = parse_date(filters[:to_date] || Date.current)

        @group_by = filters[:group_by]
      end

      def call
        executions_query = build_executions_query
        raw_data_query = build_raw_data_query

        Rails.logger.info("📊 GlobalStatisticsService - Iniciando cálculo")
        Rails.logger.info("  Período: #{@from_date} → #{@to_date}")
        Rails.logger.info("  Ejecuciones encontradas: #{executions_query.count}")
        Rails.logger.info("  Raw data encontrados: #{raw_data_query.count}")

        # Construir data base
        data = {
          period: {
            from: @from_date,
            to: @to_date,
            days: (@to_date - @from_date).to_i + 1
          },
          filters_applied: active_filters
        }

        Rails.logger.info("  Calculando executions stats...")
        data[:executions] = calculate_executions_stats(executions_query)

        Rails.logger.info("  Calculando raw_data stats...")
        data[:raw_data] = calculate_raw_data_stats(raw_data_query)

        Rails.logger.info("  Calculando by_feature...")
        data[:by_feature] = calculate_by_feature(executions_query, raw_data_query)

        Rails.logger.info("  Calculando by_status...")
        data[:by_status] = calculate_by_status(executions_query)

        Rails.logger.info("  Calculando health_score...")
        data[:health_score] = calculate_health_score(executions_query, raw_data_query)

        Rails.logger.info("  Generando alerts...")
        data[:alerts] = generate_alerts(executions_query, raw_data_query)

        # Agregar trends solo si se solicitó agrupación
        if @group_by.present?
          Rails.logger.info("  Calculando trends (#{@group_by})...")
          data[:trends] = calculate_trends(executions_query)
        end

        Rails.logger.info("✓ GlobalStatisticsService completado")

        ServiceResult.success(data: data)
      rescue StandardError => e
        Rails.logger.error("❌ Error en GlobalStatisticsService: #{e.message}")
        Rails.logger.error("   Clase: #{e.class.name}")
        Rails.logger.error("   Backtrace: #{e.backtrace.first(5).join("\n   ")}")
        ServiceResult.failure(errors: [ "Error al calcular estadísticas: #{e.message}" ])
      end

      private

      def build_executions_query
        query = IntegrationSyncExecution
          .where("started_at >= ? AND started_at <= ?",
                 @from_date.beginning_of_day,
                 @to_date.end_of_day)

        if @tenant_id
          query = query.joins(:tenant_integration_configuration)
            .where(tenant_integration_configurations: { tenant_id: @tenant_id })
        end

        query = query.where(tenant_integration_configuration_id: @integration_id) if @integration_id
        query = query.where(feature_key: @feature_key) if @feature_key

        query
      end

      def build_raw_data_query
        query = IntegrationRawData
          .where("created_at >= ? AND created_at <= ?",
                 @from_date.beginning_of_day,
                 @to_date.end_of_day)

        if @tenant_id
          query = query.joins(tenant_integration_configuration: :tenant)
            .where(tenants: { id: @tenant_id })
        end

        query = query.where(tenant_integration_configuration_id: @integration_id) if @integration_id
        query = query.where(feature_key: @feature_key) if @feature_key

        query
      end

      def calculate_executions_stats(query)
        total = query.count
        completed = query.where(status: "completed").count
        failed = query.where(status: "failed").count
        running = query.where(status: "running").count

        success_rate = total.zero? ? 0 : ((completed.to_f / total) * 100).round(2)

        avg_duration = query.where.not(duration_seconds: nil)
          .average(:duration_seconds)

        # Proteger contra nil
        avg_duration = avg_duration ? avg_duration.to_f.round(2) : 0

        {
          total: total,
          completed: completed,
          failed: failed,
          running: running,
          success_rate: success_rate,
          avg_duration_seconds: avg_duration,
          total_records_fetched: query.sum(:records_fetched) || 0,
          total_records_processed: query.sum(:records_processed) || 0,
          total_records_failed: query.sum(:records_failed) || 0
        }
      end

      def calculate_raw_data_stats(query)
        total = query.count

        by_status = query.group(:processing_status).count

        normalization_rate = if total.zero?
          0
        else
          normalized = by_status["normalized"] || 0
          ((normalized.to_f / total) * 100).round(2)
        end

        # Calcular tiempo promedio de procesamiento
        processed = query.where.not(normalized_at: nil)
        avg_processing_time = if processed.any?
          times = processed.pluck(:created_at, :normalized_at).map do |created, normalized|
            ((normalized - created) * 1000).round
          end
          (times.sum / times.size.to_f).round
        else
          0
        end

        {
          total_records: total,
          pending: by_status["pending"] || 0,
          normalized: by_status["normalized"] || 0,
          failed: by_status["failed"] || 0,
          duplicate: by_status["duplicate"] || 0,
          skipped: by_status["skipped"] || 0,
          normalization_rate: normalization_rate,
          avg_processing_time_ms: avg_processing_time
        }
      end

      def calculate_by_feature(executions_query, raw_data_query)
        features = {}

        # Por ejecuciones
        executions_query.group(:feature_key).count.each do |feature, count|
          features[feature] ||= {}
          features[feature][:executions] = count
          features[feature][:completed] = executions_query
            .where(feature_key: feature, status: "completed").count
          features[feature][:failed] = executions_query
            .where(feature_key: feature, status: "failed").count
        end

        # Por raw data
        raw_data_query.group(:feature_key).count.each do |feature, count|
          features[feature] ||= {}
          features[feature][:total_records] = count
          features[feature][:normalized] = raw_data_query
            .where(feature_key: feature, processing_status: "normalized").count
          features[feature][:failed_records] = raw_data_query
            .where(feature_key: feature, processing_status: "failed").count
        end

        features
      end

      def calculate_by_status(query)
        statuses = {}

        [ "running", "completed", "failed" ].each do |status|
          count = query.where(status: status).count
          total = query.count

          statuses[status] = {
            count: count,
            percentage: total.zero? ? 0 : ((count.to_f / total) * 100).round(2)
          }
        end

        statuses
      end

      def calculate_trends(query)
        return {} unless @group_by

        case @group_by
        when "day"
          calculate_daily_trends(query)
        when "week"
          calculate_weekly_trends(query)
        when "month"
          calculate_monthly_trends(query)
        when "feature"
          calculate_feature_trends(query)
        else
          {}
        end
      end

      def calculate_daily_trends(query)
        daily = []

        (@from_date..@to_date).each do |date|
          day_executions = query.where("DATE(started_at) = ?", date)

          total = day_executions.count
          completed = day_executions.where(status: "completed").count
          failed = day_executions.where(status: "failed").count

          daily << {
            date: date,
            total: total,
            completed: completed,
            failed: failed,
            success_rate: total.zero? ? 0 : ((completed.to_f / total) * 100).round(2)
          }
        end

        { daily: daily }
      end

      def calculate_weekly_trends(query)
        weekly = []
        current_date = @from_date.beginning_of_week

        while current_date <= @to_date
          week_end = [ current_date.end_of_week, @to_date ].min
          week_executions = query.where(started_at: current_date..week_end)

          total = week_executions.count
          completed = week_executions.where(status: "completed").count

          weekly << {
            week_start: current_date,
            week_end: week_end,
            total: total,
            completed: completed,
            failed: week_executions.where(status: "failed").count,
            success_rate: total.zero? ? 0 : ((completed.to_f / total) * 100).round(2)
          }

          current_date += 1.week
        end

        { weekly: weekly }
      end

      def calculate_monthly_trends(query)
        monthly = []
        current_date = @from_date.beginning_of_month

        while current_date <= @to_date
          month_end = [ current_date.end_of_month, @to_date ].min
          month_executions = query.where(started_at: current_date..month_end)

          total = month_executions.count
          completed = month_executions.where(status: "completed").count

          monthly << {
            month: current_date.strftime("%Y-%m"),
            month_name: I18n.l(current_date, format: "%B %Y"),
            total: total,
            completed: completed,
            failed: month_executions.where(status: "failed").count,
            success_rate: total.zero? ? 0 : ((completed.to_f / total) * 100).round(2)
          }

          current_date += 1.month
        end

        { monthly: monthly }
      end

      def calculate_feature_trends(query)
        features_over_time = {}

        query.group(:feature_key).count.keys.each do |feature|
          feature_data = []

          (@from_date..@to_date).each do |date|
            day_executions = query.where(feature_key: feature)
              .where("DATE(started_at) = ?", date)

            feature_data << {
              date: date,
              executions: day_executions.count,
              records: day_executions.sum(:records_processed)
            }
          end

          features_over_time[feature] = feature_data
        end

        { by_feature: features_over_time }
      end

      def calculate_health_score(executions_query, raw_data_query)
        exec_total = executions_query.count
        raw_total = raw_data_query.count

        return {
          score: 0,
          grade: "N/A",
          message: "Sin datos suficientes",
          factors: {}
        } if exec_total.zero?

        # Factor 1: Tasa de éxito de ejecuciones (40%)
        exec_completed = executions_query.where(status: "completed").count
        exec_success_rate = ((exec_completed.to_f / exec_total) * 100).round(2)

        # Factor 2: Tasa de normalización (30%)
        raw_normalized = raw_data_query.where(processing_status: "normalized").count
        normalization_rate = raw_total.zero? ? 0 : ((raw_normalized.to_f / raw_total) * 100).round(2)

        # Factor 3: Velocidad de procesamiento (15%)
        processed = raw_data_query.where.not(normalized_at: nil).limit(100)
        avg_time = if processed.any?
          times = processed.pluck(:created_at, :normalized_at).map { |c, n| (n - c) * 1000 }
          times.sum / times.size.to_f
        else
          0
        end
        speed_score = avg_time < 100 ? 100 : [ 100 - ((avg_time - 100) / 10), 0 ].max.round(2)

        # Factor 4: Tasa de duplicados (15%)
        duplicates = raw_data_query.where(processing_status: "duplicate").count
        duplicate_rate = raw_total.zero? ? 0 : ((duplicates.to_f / raw_total) * 100)
        duplicate_score = [ 100 - (duplicate_rate * 10), 0 ].max.round(2)

        # Calcular score ponderado
        total_score = (
          exec_success_rate * 0.4 +
          normalization_rate * 0.3 +
          speed_score * 0.15 +
          duplicate_score * 0.15
        ).round

        grade = case total_score
        when 90..100 then "A"
        when 80..89 then "B"
        when 70..79 then "C"
        when 60..69 then "D"
        else "F"
        end

        message = case grade
        when "A" then "Excelente salud del sistema"
        when "B" then "Buen rendimiento general"
        when "C" then "Rendimiento aceptable, considerar mejoras"
        when "D" then "Rendimiento bajo, revisar configuraciones"
        else "Requiere atención inmediata"
        end

        {
          score: total_score,
          grade: grade,
          message: message,
          factors: {
            execution_success: { weight: 40, score: exec_success_rate },
            normalization_rate: { weight: 30, score: normalization_rate },
            processing_speed: { weight: 15, score: speed_score },
            duplicate_control: { weight: 15, score: duplicate_score }
          }
        }
      rescue StandardError => e
        Rails.logger.error("Error calculando health_score: #{e.message}")
        {
          score: 0,
          grade: "ERROR",
          message: "Error al calcular: #{e.message}",
          factors: {}
        }
      end

      def generate_alerts(executions_query, raw_data_query)
        alerts = []

        # Alerta 1: Ejecuciones fallando consistentemente
        recent_executions = executions_query.where("started_at >= ?", 24.hours.ago)
        recent_failed = recent_executions.where(status: "failed").count
        if recent_failed >= 3
          alerts << {
            severity: "error",
            type: "consistent_failures",
            message: "#{recent_failed} ejecuciones fallidas en las últimas 24 horas",
            action: "Revisar configuración y logs de errores"
          }
        end

        # Alerta 2: Muchos registros pendientes
        pending = raw_data_query.where(processing_status: "pending").count
        if pending > 100
          alerts << {
            severity: "warning",
            type: "high_pending_count",
            message: "#{pending} registros pendientes de normalizar",
            action: "Verificar que el job de normalización esté ejecutándose"
          }
        end

        # Alerta 3: Tasa de normalización baja
        raw_total = raw_data_query.count
        if raw_total > 0
          normalized = raw_data_query.where(processing_status: "normalized").count
          rate = (normalized.to_f / raw_total) * 100

          if rate < 80
            alerts << {
              severity: "warning",
              type: "low_normalization_rate",
              message: "Tasa de normalización baja: #{rate.round(2)}%",
              action: "Revisar errores de normalización más comunes"
            }
          end
        end

        # Alerta 4: Errores de mapeo de vehículos
        vehicle_errors = raw_data_query.where(processing_status: "failed")
          .where("normalization_error LIKE ?", "%vehicle%mapping%not found%")
          .count

        if vehicle_errors > 50
          alerts << {
            severity: "info",
            type: "vehicle_mapping_errors",
            message: "#{vehicle_errors} errores de mapeo de vehículos",
            action: "Sincronizar mapeos de vehículos con el proveedor"
          }
        end

        # Alerta 5: Sin actividad reciente
        last_execution = executions_query.maximum(:started_at)
        if last_execution && last_execution < 48.hours.ago
          alerts << {
            severity: "warning",
            type: "no_recent_activity",
            message: "Sin sincronizaciones desde #{I18n.l(last_execution, format: :long)}",
            action: "Verificar configuraciones activas y scheduler"
          }
        end

        alerts
      end

      def active_filters
        {
          tenant_id: @tenant_id,
          integration_id: @integration_id,
          feature_key: @feature_key,
          from_date: @from_date,
          to_date: @to_date,
          group_by: @group_by
        }.compact
      end

      # Método helper para parsear fechas consistentemente
      def parse_date(value)
        return Date.current if value.nil?
        return value.to_date if value.respond_to?(:to_date)
        Date.parse(value.to_s)
      rescue ArgumentError
        Date.current
      end
    end
  end
end
