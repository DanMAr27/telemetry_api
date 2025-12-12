# app/api/entities/vehicle_entity.rb
module Entities
  class VehicleEntity < Grape::Entity
    expose :id
    expose :company_id
    expose :name
    expose :license_plate
    expose :vin
    expose :brand
    expose :model
    expose :year
    expose :fuel_type # combustion, electric, hybrid
    expose :tank_capacity_liters
    expose :battery_capacity_kwh
    expose :is_active
    expose :created_at
    expose :updated_at

    # Telemetría
    expose :has_telemetry do |instance|
      instance.vehicle_telemetry_config.present?
    end

    expose :telemetry_provider, if: ->(instance, options) { instance.vehicle_telemetry_config.present? } do |instance|
      instance.vehicle_telemetry_config&.provider_name
    end

    # Relaciones opcionales
    expose :company, using: CompanyEntity, if: ->(instance, options) { options[:include_company] }
    expose :telemetry_config, using: VehicleTelemetryConfigEntity, if: ->(instance, options) { options[:include_telemetry_config] }

    # Estadísticas opcionales
    expose :stats, if: ->(instance, options) { options[:include_stats] } do
      expose :total_refuels do |instance|
        instance.refuels.count
      end

      expose :total_charges do |instance|
        instance.electric_charges.count
      end

      expose :last_refuel_date do |instance|
        instance.refuels.maximum(:refuel_date)
      end

      expose :last_charge_date do |instance|
        instance.electric_charges.maximum(:start_time)
      end
    end
  end
end
