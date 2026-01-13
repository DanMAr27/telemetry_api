# app/services/integrations/vehicle_mappings/create_mapping_service.rb
module Integrations
  module VehicleMappings
    class CreateMappingService
      def initialize(config, vehicle, external_vehicle_id, external_vehicle_name = nil, valid_from = nil)
        @config = config
        @vehicle = vehicle
        @external_vehicle_id = external_vehicle_id
        @external_vehicle_name = external_vehicle_name
        @valid_from = valid_from || Time.current
      end

      def call
        # Remove blocking check for existing mapping to allow historical recycling.
        # Logic is handled by deactivate_collisions (implicitly in activate!) if we want to force takeover,
        # OR we can warn. But user requirement implies we just "associate" it.

        # Build as inactive first to avoid validation collision on 'active uniqueness' if another exists
        mapping = @config.vehicle_provider_mappings.build(
          vehicle: @vehicle,
          external_vehicle_id: @external_vehicle_id,
          external_vehicle_name: @external_vehicle_name,
          is_active: false # Start inactive
        )

        if mapping.save
          # Now activate it! (This will close previous owners of this ID or previous mappings of this Vehicle)
          mapping.activate!(start_time: @valid_from)

          # Reload to return full state
          mapping.reload

          ServiceResult.success(
            data: mapping,
            message: "Mapeo creado y activado exitosamente"
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
