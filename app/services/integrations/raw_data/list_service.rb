# app/services/integrations/raw_data/list_service.rb
module Integrations
  module RawData
    class ListService
      def initialize(filters: {})
        @filters = filters
      end

      def call
        query = build_query
        total = query.count

        # Aplicar paginación
        page = @filters[:page] || 1
        per_page = [ @filters[:per_page] || 50, 500 ].min

        paginated_records = query.offset((page - 1) * per_page).limit(per_page)

        # Calcular summary (optimizado)
        summary = calculate_summary(query, total)

        ServiceResult.success(
          data: {
            raw_data: paginated_records,
            total: total,
            total_pages: (total.to_f / per_page).ceil,
            summary: summary,
            pagination: {
              current_page: page,
              per_page: per_page,
              total_items: total,
              total_pages: (total.to_f / per_page).ceil,
              next_page: page < (total.to_f / per_page).ceil ? page + 1 : nil,
              prev_page: page > 1 ? page - 1 : nil
            }
          }
        )
      rescue => e
        ServiceResult.failure(errors: [ "Error al listar raw data: #{e.message}" ])
      end

      private

      def build_query
        query = IntegrationRawData.all

        # Includes para optimizar
        query = query.includes(:tenant_integration_configuration,
                               :integration_sync_execution,
                               :normalized_record)

        # Filtros básicos
        query = query.where(tenant_id: @filters[:tenant_id]) if @filters[:tenant_id]
        query = query.where(tenant_integration_configuration_id: @filters[:integration_id]) if @filters[:integration_id]
        query = query.where(feature_key: @filters[:feature_key]) if @filters[:feature_key]
        query = query.where(provider_slug: @filters[:provider_slug]) if @filters[:provider_slug]
        query = query.where(external_id: @filters[:external_id]) if @filters[:external_id]

        # Filtro de estado
        if @filters[:status].present?
          query = query.where(processing_status: @filters[:status])
        elsif @filters[:status_in].present?
          query = query.where(processing_status: @filters[:status_in])
        end

        # Filtros de fecha
        if @filters[:from_date]
          query = query.where("created_at >= ?", @filters[:from_date].beginning_of_day)
        end

        if @filters[:to_date]
          query = query.where("created_at <= ?", @filters[:to_date].end_of_day)
        end

        if @filters[:created_after]
          query = query.where("created_at >= ?", @filters[:created_after])
        end

        if @filters[:created_before]
          query = query.where("created_at <= ?", @filters[:created_before])
        end

        # Filtro de sync execution
        query = query.where(integration_sync_execution_id: @filters[:sync_execution_id]) if @filters[:sync_execution_id]

        if @filters[:only_latest_sync] && @filters[:integration_id]
          latest_exec = IntegrationSyncExecution
            .where(tenant_integration_configuration_id: @filters[:integration_id])
            .order(started_at: :desc)
            .first

          query = query.where(integration_sync_execution_id: latest_exec&.id) if latest_exec
        end

        # Filtros de error
        if @filters[:has_error] == true
          query = query.where.not(normalization_error: nil)
        elsif @filters[:has_error] == false
          query = query.where(normalization_error: nil)
        end

        if @filters[:error_contains]
          query = query.where("normalization_error LIKE ?", "%#{@filters[:error_contains]}%")
        end

        if @filters[:retriable] == true
          query = query.where(processing_status: "failed").select do |record|
            record.retriable_error?
          end
        end

        # Filtro de tipo normalizado
        query = query.where(normalized_record_type: @filters[:normalized_type]) if @filters[:normalized_type]

        if @filters[:has_normalized_record] == true
          query = query.where.not(normalized_record_id: nil)
        elsif @filters[:has_normalized_record] == false
          query = query.where(normalized_record_id: nil)
        end

        # Ordenamiento
        sort_by = @filters[:sort_by] || "created_at"
        sort_order = @filters[:sort_order] || "desc"

        query = query.order("#{sort_by} #{sort_order}")

        query
      end

      def calculate_summary(query, total)
        # Usar reorder(nil) para remover el ORDER BY antes del GROUP BY
        by_status = query.reorder(nil).group(:processing_status).count

        {
          total: total,
          by_status: {
            pending: by_status["pending"] || 0,
            normalized: by_status["normalized"] || 0,
            failed: by_status["failed"] || 0,
            duplicate: by_status["duplicate"] || 0,
            skipped: by_status["skipped"] || 0
          },
          filters_applied: @filters.reject { |k, v| v.nil? || v == false }
        }
      end
    end
  end
end
