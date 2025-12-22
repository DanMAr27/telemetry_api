# app/services/integrations/raw_data/statistics_service.rb
module Integrations
  module RawData
    class StatisticsService
      def initialize(filters: {})
        @filters = filters
        @from_date = filters[:from_date] || 30.days.ago.to_date
        @to_date = filters[:to_date] || Date.current
      end

      def call
        query = build_base_query

        data = {
          period: {
            from: @from_date,
            to: @to_date,
            days: (@to_date - @from_date).to_i + 1
          },
          totals: calculate_totals(query),
          rates: calculate_rates(query),
          by_status: calculate_by_status(query),
          by_feature: calculate_by_feature(query),
          by_provider: calculate_by_provider(query),
          error_breakdown: calculate_error_breakdown(query),
          trends: calculate_trends(query),
          health_score: calculate_health_score(query),
          alerts: generate_alerts(query)
        }

        ServiceResult.success(data: data)
      rescue => e
        ServiceResult.failure(errors: [ "Error al calcular estadísticas: #{e.message}" ])
      end

      private

      def build_base_query
        query = IntegrationRawData.where("created_at >= ? AND created_at <= ?",
                                          @from_date.beginning_of_day,
                                          @to_date.end_of_day)

        query = query.where(tenant_integration_configuration_id: @filters[:integration_id]) if @filters[:integration_id]
        query = query.where(tenant_id: @filters[:tenant_id]) if @filters[:tenant_id]

        query
      end

      def calculate_totals(query)
        total = query.count
        by_status = query.group(:processing_status).count

        {
          total_records: total,
          pending: by_status["pending"] || 0,
          normalized: by_status["normalized"] || 0,
          failed: by_status["failed"] || 0,
          duplicate: by_status["duplicate"] || 0,
          skipped: by_status["skipped"] || 0
        }
      end

      def calculate_rates(query)
        total = query.count
        return { success_rate: 0, failure_rate: 0, duplicate_rate: 0 } if total.zero?

        normalized = query.where(processing_status: "normalized").count
        failed = query.where(processing_status: "failed").count
        duplicate = query.where(processing_status: "duplicate").count

        # Calcular tiempo promedio de procesamiento
        processed = query.where.not(normalized_at: nil)
        avg_time = if processed.any?
          processed.pluck(:created_at, :normalized_at).map do |created, normalized|
            ((normalized - created) * 1000).round
          end.sum / processed.count.to_f
        else
          0
        end

        {
          success_rate: ((normalized.to_f / total) * 100).round(2),
          failure_rate: ((failed.to_f / total) * 100).round(2),
          duplicate_rate: ((duplicate.to_f / total) * 100).round(2),
          avg_processing_time_ms: avg_time.round
        }
      end

      def calculate_by_status(query)
        total = query.count

        statuses = {}

        [ "pending", "normalized", "failed", "duplicate", "skipped" ].each do |status|
          count = query.where(processing_status: status).count

          statuses[status] = {
            count: count,
            percentage: total.zero? ? 0 : ((count.to_f / total) * 100).round(2)
          }

          # Info adicional según status
          case status
          when "pending"
            pending_records = query.where(processing_status: "pending").order(created_at: :asc)
            statuses[status][:oldest] = pending_records.first&.created_at
            statuses[status][:newest] = pending_records.last&.created_at

          when "normalized"
            processed = query.where(processing_status: "normalized").where.not(normalized_at: nil)
            if processed.any?
              avg = processed.pluck(:created_at, :normalized_at).map do |c, n|
                ((n - c) * 1000).round
              end.sum / processed.count.to_f

              statuses[status][:avg_processing_time_ms] = avg.round
            end

          when "failed"
            failed = query.where(processing_status: "failed")
            retriable = failed.select { |r| r.retriable_error? }.count

            statuses[status][:retriable] = retriable
            statuses[status][:permanent] = count - retriable
          end
        end

        statuses
      end

      def calculate_by_feature(query)
        features = {}

        query.group(:feature_key).count.each do |feature, count|
          feature_query = query.where(feature_key: feature)

          features[feature] = {
            total: count,
            normalized: feature_query.where(processing_status: "normalized").count,
            failed: feature_query.where(processing_status: "failed").count,
            duplicate: feature_query.where(processing_status: "duplicate").count,
            pending: feature_query.where(processing_status: "pending").count
          }
        end

        features
      end

      def calculate_by_provider(query)
        providers = {}

        query.group(:provider_slug).count.each do |provider, count|
          provider_query = query.where(provider_slug: provider)
          normalized = provider_query.where(processing_status: "normalized").count
          failed = provider_query.where(processing_status: "failed").count

          providers[provider] = {
            total: count,
            success_rate: count.zero? ? 0 : ((normalized.to_f / count) * 100).round(2),
            failure_rate: count.zero? ? 0 : ((failed.to_f / count) * 100).round(2)
          }
        end

        providers
      end

      def calculate_error_breakdown(query)
        failed = query.where(processing_status: "failed")
        total_failed = failed.count

        return {} if total_failed.zero?

        errors = {}

        # Agrupar por tipo de error
        failed.find_each do |record|
          error_type = detect_error_type(record)
          errors[error_type] ||= { count: 0, retriable: false }
          errors[error_type][:count] += 1
          errors[error_type][:retriable] = true if record.retriable_error?
        end

        # Calcular porcentajes
        errors.transform_values do |data|
          data.merge(
            percentage: ((data[:count].to_f / total_failed) * 100).round(2)
          )
        end

        errors.sort_by { |k, v| -v[:count] }.to_h
      end

      def calculate_trends(query)
        return { daily: [] } unless @filters[:group_by]

        case @filters[:group_by]
        when "day"
          calculate_daily_trends(query)
        when "hour"
          calculate_hourly_trends(query)
        else
          { daily: [] }
        end
      end

      def calculate_daily_trends(query)
        daily = []

        (@from_date..@to_date).each do |date|
          day_query = query.where("DATE(created_at) = ?", date)
          total = day_query.count
          normalized = day_query.where(processing_status: "normalized").count
          failed = day_query.where(processing_status: "failed").count

          daily << {
            date: date,
            total: total,
            normalized: normalized,
            failed: failed,
            success_rate: total.zero? ? 0 : ((normalized.to_f / total) * 100).round(2)
          }
        end

        { daily: daily }
      end

      def calculate_hourly_trends(query)
        # Implementar si se necesita
        { hourly: [] }
      end

      def calculate_health_score(query)
        total = query.count
        return { score: 0, grade: "F", factors: {} } if total.zero?

        # Factores de salud
        normalized = query.where(processing_status: "normalized").count
        failed = query.where(processing_status: "failed").count
        pending = query.where(processing_status: "pending").count

        success_rate = ((normalized.to_f / total) * 100).round(2)

        # Calcular velocidad de procesamiento
        processed = query.where.not(normalized_at: nil).limit(100)
        avg_time = if processed.any?
          processed.pluck(:created_at, :normalized_at).map do |c, n|
            ((n - c) * 1000).round
          end.sum / processed.count.to_f
        else
          0
        end

        # Scoring
        success_score = success_rate
        speed_score = avg_time < 100 ? 100 : (10000 / avg_time.to_f).clamp(0, 100)
        error_recovery_score = failed.zero? ? 100 : [ 100 - (failed * 2), 0 ].max
        duplicate_score = query.where(processing_status: "duplicate").count < (total * 0.01) ? 100 : 70

        # Score ponderado
        total_score = (
          success_score * 0.4 +
          speed_score * 0.2 +
          error_recovery_score * 0.2 +
          duplicate_score * 0.2
        ).round

        # Grado
        grade = case total_score
        when 90..100 then "A"
        when 80..89 then "B"
        when 70..79 then "C"
        when 60..69 then "D"
        else "F"
        end

        {
          score: total_score,
          grade: grade,
          factors: {
            success_rate: { weight: 40, score: success_rate.round(2) },
            processing_speed: { weight: 20, score: speed_score.round(2) },
            error_recovery: { weight: 20, score: error_recovery_score.round(2) },
            duplicate_rate: { weight: 20, score: duplicate_score.round(2) }
          }
        }
      end

      def generate_alerts(query)
        alerts = []

        # Alerta de pending alto
        pending = query.where(processing_status: "pending").count
        if pending > 50
          alerts << {
            severity: "warning",
            message: "#{pending} registros pendientes de procesar (inusualmente alto)",
            action: "Verificar estado del job de normalización"
          }
        end

        # Alerta de errores frecuentes
        failed = query.where(processing_status: "failed")
        vehicle_not_found = failed.select { |r| r.normalization_error&.include?("mapping not found") }.count

        if vehicle_not_found > 100
          alerts << {
            severity: "info",
            message: "#{vehicle_not_found} errores 'vehicle_not_found' - considerar sincronizar mapeos",
            action: "Ejecutar sincronización de vehículos"
          }
        end

        # Alerta de tasa de éxito baja
        total = query.count
        if total > 0
          success_rate = (query.where(processing_status: "normalized").count.to_f / total) * 100
          if success_rate < 80
            alerts << {
              severity: "warning",
              message: "Tasa de éxito baja: #{success_rate.round(2)}%",
              action: "Revisar configuración y logs de errores"
            }
          end
        end

        alerts
      end

      def detect_error_type(record)
        return "unknown" unless record.normalization_error

        error_msg = record.normalization_error.downcase

        case error_msg
        when /vehicle mapping not found|vehicle not found/
          "vehicle_not_found"
        when /authentication|credentials/
          "authentication_error"
        when /invalid.*format/
          "invalid_data_format"
        when /missing.*field/
          "missing_required_field"
        when /duplicate/
          "duplicate_detection"
        else
          "normalization_error"
        end
      end
    end
  end
end
