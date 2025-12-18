# app/api/entities/vehicle_electric_charge_entity.rb
module Entities
  class VehicleElectricChargeEntity < Grape::Entity
    expose :id
    expose :tenant_id
    expose :vehicle_id
    expose :integration_raw_data_id
    expose :charge_start_time
    expose :charge_end_time
    expose :duration_minutes
    expose :location_lat
    expose :location_lng
    expose :charge_type
    expose :start_soc_percent
    expose :end_soc_percent
    expose :energy_consumed_kwh
    expose :peak_power_kw
    expose :odometer_km
    expose :is_estimated
    expose :max_ac_voltage
    expose :provider_metadata, if: { include_metadata: true }
    expose :created_at
    expose :updated_at

    # Relaciones opcionales
    expose :vehicle, using: Entities::VehicleEntity, if: { include_vehicle: true }
    expose :integration_raw_data,
           using: Entities::IntegrationRawDataEntity,
           if: { include_raw_data: true }

    # Campos computados
    expose :soc_gained, if: { include_computed: true } do |charge, _options|
      charge.soc_gained
    end

    expose :duration_hours, if: { include_computed: true } do |charge, _options|
      charge.duration_hours
    end

    expose :average_power_kw, if: { include_computed: true } do |charge, _options|
      charge.average_power_kw
    end

    expose :has_location, if: { include_computed: true } do |charge, _options|
      charge.has_location?
    end

    expose :from_integration, if: { include_computed: true } do |charge, _options|
      charge.from_integration?
    end

    expose :is_fast_charge, if: { include_computed: true } do |charge, _options|
      charge.is_fast_charge?
    end

    expose :is_complete_charge, if: { include_computed: true } do |charge, _options|
      charge.is_complete_charge?
    end

    expose :coordinates, if: { include_computed: true } do |charge, _options|
      charge.coordinates
    end

    expose :description, if: { include_computed: true } do |charge, _options|
      charge.description
    end

    # Información del vehículo (básica)
    expose :vehicle_info, unless: { include_vehicle: true } do |charge, _options|
      {
        id: charge.vehicle.id,
        name: charge.vehicle.name,
        license_plate: charge.vehicle.license_plate
      }
    end

    # Badges
    expose :data_source_badge do |charge, _options|
      charge.from_integration? ? "integration" : "manual"
    end

    expose :charge_type_badge do |charge, _options|
      charge.is_fast_charge? ? "fast" : "slow"
    end

    expose :estimation_badge do |charge, _options|
      charge.is_estimated ? "estimated" : "measured"
    end
  end
end
