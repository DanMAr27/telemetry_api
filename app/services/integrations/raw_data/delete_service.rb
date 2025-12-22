# app/services/integrations/raw_data/delete_service.rb
module Integrations
  module RawData
    class DeleteService
      MAX_RECORDS = 1000

      def initialize(ids:, reason:, notes: nil, confirm: false)
        @ids = normalize_ids(ids)
        @reason = reason
        @notes = notes
        @confirm = confirm
        validate!
      end

      def call
        unless @confirm
          return ServiceResult.failure(
            errors: [ "Debe confirmar la eliminación con confirm: true" ]
          )
        end

        start_time = Time.current
        results = []

        records = IntegrationRawData.where(id: @ids)

        if records.empty?
          return ServiceResult.failure(
            errors: [ "No se encontraron registros con los IDs proporcionados" ]
          )
        end

        records.find_each do |raw_data|
          result = delete_single_record(raw_data)
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
          errors: [ "Error al eliminar: #{e.message}" ]
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

      def delete_single_record(raw_data)
        # Guardar metadata antes de eliminar
        raw_data.update!(
          metadata: (raw_data.metadata || {}).merge(
            deleted_at: Time.current.iso8601,
            delete_reason: @reason,
            delete_notes: @notes,
            deleted_status: raw_data.processing_status
          ).compact
        )

        # Soft delete
        if raw_data.respond_to?(:deleted_at=)
          raw_data.update!(deleted_at: Time.current)
        else
          raw_data.update!(processing_status: "deleted")
        end

        {
          id: raw_data.id,
          success: true,
          deleted_at: Time.current
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

        "#{successful} de #{total} registros eliminados correctamente"
      end
    end
  end
end
