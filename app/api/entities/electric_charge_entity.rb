# app/api/entities/electric_charge_entity.rb
module Entities
  class ElectricChargeEntity < Grape::Entity
    expose :id
    expose :vehicle_id
    expose :external_id
    expose :provider_name
    expose :start_time
    expose :duration_minutes
    expose :energy_consumed_kwh
    expose :start_soc_percent
    expose :end_soc_percent
    expose :charge_type
    expose :charge_is_estimated
    expose :odometer_km
    expose :peak_power_kw
    expose :measured_charger_energy_in_kwh
    expose :measured_battery_energy_in_kwh
    expose :created_at
    expose :updated_at

    # Ubicación
    expose :location, if: ->(instance, options) { instance.has_location? } do
      expose :latitude do |instance|
        instance.location_lat
      end
      expose :longitude do |instance|
        instance.location_lng
      end
      expose :coordinates do |instance|
        instance.coordinates
      end
    end

    # Métricas calculadas
    expose :metrics, if: ->(instance, options) { options[:include_calculations] } do
      expose :soc_gained_percent do |instance|
        instance.soc_gained_percent
      end
      expose :charging_efficiency_percent do |instance|
        instance.charging_efficiency_percent
      end
      expose :duration_hours do |instance|
        instance.duration_hours
      end
      expose :average_power_kw do |instance|
        instance.average_power_kw
      end
    end

    # Anomalías
    expose :anomalies, if: ->(instance, options) { options[:include_anomalies] } do
      expose :low_efficiency do |instance|
        instance.low_efficiency?
      end
    end

    # Tipo de carga
    expose :is_fast_charge do |instance|
      instance.fast_charge?
    end

    expose :is_slow_charge do |instance|
      instance.slow_charge?
    end

    # Datos raw solo para admins
    expose :raw_data, if: ->(instance, options) { options[:admin_view] }

    # Relaciones
    expose :vehicle, using: VehicleEntity, if: ->(instance, options) { options[:include_vehicle] }
  end
end
