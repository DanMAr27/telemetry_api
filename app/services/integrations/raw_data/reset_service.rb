# app/services/integrations/raw_data/reset_service.rb
module Integrations
  module RawData
    class ResetService
      MAX_RECORDS = 1000

      def initialize(ids:, notes: nil)
        @ids = normalize_ids(ids)
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
          result = reset_single_record(raw_data)
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
          errors: [ "Error al resetear: #{e.message}" ]
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

        if @ids.size > MAX_RECORDS
          raise ArgumentError, "Máximo #{MAX_RECORDS} registros por operación"
        end
      end

      def reset_single_record(raw_data)
        unless raw_data.can_be_reset?
          return {
            id: raw_data.id,
            success: false,
            error: "Estado no permite reset: #{raw_data.processing_status}"
          }
        end

        previous_status = raw_data.processing_status

        raw_data.reset_for_reprocessing!
        raw_data.update!(
          metadata: (raw_data.metadata || {}).merge(
            reset_at: Time.current.iso8601,
            reset_from_status: previous_status,
            reset_notes: @notes
          ).compact
        )

        {
          id: raw_data.id,
          success: true,
          previous_status: previous_status,
          new_status: "pending"
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

        "#{successful} de #{total} registros reseteados a pending"
      end
    end
  end
end
