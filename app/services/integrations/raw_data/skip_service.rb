# app/services/integrations/raw_data/skip_service.rb
module Integrations
  module RawData
    class SkipService
      MAX_RECORDS = 1000

      def initialize(ids:, reason:, notes: nil)
        @ids = normalize_ids(ids)
        @reason = reason
        @notes = notes
        validate!
      end

      def call
        start_time = Time.current
        results = []

        records = IntegrationRawData.where(id: @ids)

        if records.empty?
          return ServiceResult.failure(
            errors: [ "No se encontraron registros con los IDs proporcionados" ]
          )
        end

        records.find_each do |raw_data|
          result = skip_single_record(raw_data)
          results << result
        end

        duration = (Time.current - start_time).round(2)

        ServiceResult.success(
          data: {
            total: @ids.size,
            successful: results.count { |r| r[:success] },
            failed: results.count { |r| !r[:success] },
            results: results,
            duration_seconds: duration
          },
          message: build_summary_message(results)
        )
      rescue StandardError => e
        ServiceResult.failure(
          errors: [ "Error al omitir: #{e.message}" ]
        )
      end

      private

      def normalize_ids(ids)
        Array(ids).compact.uniq.first(MAX_RECORDS)
      end

      def validate!
        if @ids.empty?
          raise ArgumentError, "Debe proporcionar al menos un ID"
        end

        if @reason.blank?
          raise ArgumentError, "Debe proporcionar un motivo (reason)"
        end

        if @ids.size > MAX_RECORDS
          raise ArgumentError, "Máximo #{MAX_RECORDS} registros por operación"
        end
      end

      def skip_single_record(raw_data)
        unless raw_data.can_be_skipped?
          return {
            id: raw_data.id,
            success: false,
            error: "Estado no permite omisión: #{raw_data.processing_status}"
          }
        end

        raw_data.mark_as_skipped!(@reason)

        # Actualizar metadata con notas si existen
        if @notes.present?
          raw_data.update!(
            metadata: (raw_data.metadata || {}).merge(
              skip_notes: @notes
            )
          )
        end

        {
          id: raw_data.id,
          success: true,
          previous_status: raw_data.processing_status_was,
          new_status: "skipped"
        }
      rescue StandardError => e
        {
          id: raw_data.id,
          success: false,
          error: e.message
        }
      end

      def build_summary_message(results)
        successful = results.count { |r| r[:success] }
        total = results.size

        "#{successful} de #{total} registros omitidos exitosamente"
      end
    end
  end
end
