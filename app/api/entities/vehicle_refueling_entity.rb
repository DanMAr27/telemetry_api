# app/api/entities/vehicle_refueling_entity.rb
module Entities
  class VehicleRefuelingEntity < Grape::Entity
    expose :id
    expose :tenant_id
    expose :vehicle_id
    expose :integration_raw_data_id
    expose :refueling_date
    expose :location_lat
    expose :location_lng
    expose :volume_liters
    expose :cost
    expose :currency
    expose :odometer_km
    expose :fuel_type do |refueling, _options|
      refueling.fuel_type&.name || "Unknown"
    end
    expose :fuel_type_code do |refueling, _options|
      refueling.fuel_type&.code
    end
    expose :confidence_level
    expose :is_estimated
    expose :tank_capacity_liters
    expose :provider_metadata, if: { include_metadata: true }
    expose :created_at
    expose :updated_at
    expose :vehicle, using: Entities::VehicleEntity, if: { include_vehicle: true }
    expose :integration_raw_data,
           using: Entities::IntegrationRawDataEntity,
           if: { include_raw_data: true }
    expose :cost_per_liter, if: { include_computed: true } do |refueling, _options|
      refueling.cost_per_liter
    end
    expose :has_location, if: { include_computed: true } do |refueling, _options|
      refueling.has_location?
    end
    expose :has_cost, if: { include_computed: true } do |refueling, _options|
      refueling.has_cost?
    end
    expose :from_integration, if: { include_computed: true } do |refueling, _options|
      refueling.from_integration?
    end
    expose :coordinates, if: { include_computed: true } do |refueling, _options|
      refueling.coordinates
    end
    expose :description, if: { include_computed: true } do |refueling, _options|
      refueling.description
    end
    expose :vehicle_info, unless: { include_vehicle: true } do |refueling, _options|
      {
        id: refueling.vehicle.id,
        name: refueling.vehicle.name,
        license_plate: refueling.vehicle.license_plate
      }
    end
    expose :data_source_badge do |refueling, _options|
      refueling.from_integration? ? "integration" : "manual"
    end
    expose :estimation_badge do |refueling, _options|
      refueling.is_estimated ? "estimated" : "measured"
    end
  end
end
