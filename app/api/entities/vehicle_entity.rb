# app/api/entities/vehicle_entity.rb
module Entities
  class VehicleEntity < Grape::Entity
    expose :id
    expose :name
    expose :license_plate
    expose :brand
    expose :model
    expose :fuel_type
    expose :is_electric
    expose :vin
    expose :year
    expose :vehicle_type
    expose :status
    expose :tank_capacity_liters
    expose :battery_capacity_kwh
    expose :initial_odometer_km
    expose :current_odometer_km
    expose :total_km_driven
    expose :acquisition_date
    expose :last_maintenance_date
    expose :next_maintenance_date
    expose :metadata
    expose :created_at
    expose :updated_at

    expose :has_telemetry do |vehicle, _options|
      vehicle.has_telemetry?
    end

    expose :telemetry_info, if: ->(vehicle, options) { options[:include_telemetry] } do |vehicle, _options|
      if vehicle.has_telemetry?
        # Find active mapping
        mapping = vehicle.vehicle_provider_mappings.active.first
        if mapping
          {
            provider_slug: mapping.integration_provider.slug,
             external_id: mapping.external_vehicle_id,
             connected_at: mapping.valid_from
          }
        end
      end
    end
  end
end
