# app/services/integrations/raw_data/retry_service.rb
module Integrations
  module RawData
    class RetryService
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
          result = retry_single_record(raw_data)
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
          errors: [ "Error al reintentar: #{e.message}" ]
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

      def retry_single_record(raw_data)
        unless raw_data.can_be_normalized?
          return {
            id: raw_data.id,
            success: false,
            error: "Estado no permite normalización: #{raw_data.processing_status}"
          }
        end

        # Obtener config y normalizer
        config = raw_data.tenant_integration_configuration
        normalizer = Integrations::Factories::NormalizerFactory.build(
          raw_data.provider_slug,
          raw_data.feature_key
        )

        # Intentar normalizar
        result = normalizer.normalize(raw_data, config)

        if result.success?
          raw_data.mark_as_normalized!(result.data)
          {
            id: raw_data.id,
            success: true,
            normalized_record_id: result.data.id,
            normalized_record_type: result.data.class.name
          }
        else
          raw_data.mark_as_failed!(result.errors.join(", "))
          {
            id: raw_data.id,
            success: false,
            error: result.errors.join(", ")
          }
        end
      rescue StandardError => e
        raw_data.mark_as_failed!("Error inesperado: #{e.message}")
        {
          id: raw_data.id,
          success: false,
          error: e.message
        }
      end

      def build_summary_message(results)
        successful = results.count { |r| r[:success] }
        total = results.size

        if successful == total
          "#{successful} registros reintentados exitosamente"
        elsif successful.zero?
          "Todos los registros fallaron al reintentar"
        else
          "#{successful} de #{total} registros reintentados exitosamente"
        end
      end
    end
  end
end
