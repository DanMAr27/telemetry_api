# app/services/integrations/raw_data/get_detail_service.rb
module Integrations
  module RawData
    class GetDetailService
      def initialize(id:, options: {})
        @id = id
        @options = options
      end

      def call
        raw_data = IntegrationRawData
          .includes(:tenant_integration_configuration,
                    :integration_sync_execution,
                    :normalized_record,
                    :tenant_integration_configuration)
          .find_by(id: @id)

        unless raw_data
          return ServiceResult.failure(errors: [ "Registro no encontrado" ])
        end
        data = raw_data
        if @options[:include_similar]
          data.define_singleton_method(:similar_records) do
            find_similar_records(raw_data)
          end
        end

        ServiceResult.success(data: data)
      rescue => e
        ServiceResult.failure(errors: [ "Error al obtener detalle: #{e.message}" ])
      end

      private

      def find_similar_records(raw_data)
        return nil unless raw_data.processing_status == "failed"
        key_error = extract_key_error_part(raw_data.normalization_error)

        similar = IntegrationRawData
          .where(tenant_integration_configuration_id: raw_data.tenant_integration_configuration_id)
          .where(processing_status: "failed")
          .where.not(id: raw_data.id)
          .where("normalization_error LIKE ?", "%#{key_error}%")
          .limit(5)

        similar
      end

      def extract_key_error_part(error_message)
        return "" unless error_message

        # Si contiene "vehicle mapping", extraer el external_id
        if error_message.include?("mapping not found")
          match = error_message.match(/external_id[:\s]+([a-zA-Z0-9_-]+)/)
          return "external_id: #{match[1]}" if match
        end

        # Si es otro tipo de error, tomar las primeras palabras clave
        error_message.split(":").first&.strip || error_message[0..50]
      end
    end
  end
end
