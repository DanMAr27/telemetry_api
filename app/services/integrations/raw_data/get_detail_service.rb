# app/services/integrations/raw_data/get_detail_service.rb
module Integrations
  module RawData
    class GetDetailService
      def initialize(id:)
        @id = id
      end

      def call
        raw_data = IntegrationRawData
          .includes(
            :tenant_integration_configuration,
            :integration_sync_execution,
            :normalized_record,
            tenant_integration_configuration: [ :integration_provider, :tenant ]
          )
          .find_by(id: @id)

        unless raw_data
          return ServiceResult.failure(errors: [ "Registro no encontrado" ])
        end

        ServiceResult.success(data: raw_data)
      rescue StandardError => e
        ServiceResult.failure(errors: [ "Error al obtener detalle: #{e.message}" ])
      end
    end
  end
end
