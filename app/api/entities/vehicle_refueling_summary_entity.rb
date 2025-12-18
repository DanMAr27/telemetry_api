# app/api/entities/vehicle_refueling_summary_entity.rb
module Entities
  class VehicleRefuelingSummaryEntity < Grape::Entity
    expose :id
    expose :refueling_date
    expose :volume_liters
    expose :cost
    expose :currency
    expose :odometer_km
    expose :fuel_type
    expose :is_estimated

    expose :vehicle_info do |refueling, _options|
      {
        id: refueling.vehicle.id,
        name: refueling.vehicle.name,
        license_plate: refueling.vehicle.license_plate
      }
    end

    expose :cost_per_liter do |refueling, _options|
      refueling.cost_per_liter
    end

    expose :from_integration do |refueling, _options|
      refueling.from_integration?
    end
  end
end
