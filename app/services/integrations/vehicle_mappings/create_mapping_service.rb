# app/services/integrations/vehicle_mappings/create_mapping_service.rb
module Integrations
  module VehicleMappings
    class CreateMappingService
      def initialize(config, vehicle, external_vehicle_id, external_vehicle_name = nil)
        @config = config
        @vehicle = vehicle
        @external_vehicle_id = external_vehicle_id
        @external_vehicle_name = external_vehicle_name
      end

      def call
        # Verificar si ya existe mapeo para este external_vehicle_id
        existing = @config.vehicle_provider_mappings.find_by(
          external_vehicle_id: @external_vehicle_id
        )

        if existing
          return ServiceResult.failure(
            errors: [ "El vehículo externo '#{@external_vehicle_id}' ya está mapeado" ]
          )
        end
        mapping = @config.vehicle_provider_mappings.build(
          vehicle: @vehicle,
          external_vehicle_id: @external_vehicle_id,
          external_vehicle_name: @external_vehicle_name,
          is_active: true,
          mapped_at: Time.current
        )

        if mapping.save
          ServiceResult.success(
            data: mapping,
            message: "Mapeo creado exitosamente"
          )
        else
          ServiceResult.failure(errors: mapping.errors.full_messages)
        end

      rescue StandardError => e
        Rails.logger.error("Error al crear mapeo: #{e.message}")
        ServiceResult.failure(errors: [ e.message ])
      end
    end
  end
end
