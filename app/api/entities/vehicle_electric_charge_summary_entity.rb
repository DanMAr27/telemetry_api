# app/api/entities/vehicle_electric_charge_summary_entity.rb
module Entities
  class VehicleElectricChargeSummaryEntity < Grape::Entity
    expose :id
    expose :charge_start_time
    expose :duration_minutes
    expose :charge_type
    expose :start_soc_percent
    expose :end_soc_percent
    expose :energy_consumed_kwh
    expose :is_estimated

    expose :vehicle_info do |charge, _options|
      {
        id: charge.vehicle.id,
        name: charge.vehicle.name,
        license_plate: charge.vehicle.license_plate
      }
    end

    expose :soc_gained do |charge, _options|
      charge.soc_gained
    end

    expose :duration_hours do |charge, _options|
      charge.duration_hours
    end

    expose :from_integration do |charge, _options|
      charge.from_integration?
    end

    expose :is_complete do |charge, _options|
      charge.is_complete_charge?
    end
  end
end
