# app/api/entities/refuel_entity.rb
module Entities
  class RefuelEntity < Grape::Entity
    expose :id
    expose :vehicle_id
    expose :external_id
    expose :provider_name
    expose :refuel_date
    expose :volume_liters
    expose :cost
    expose :currency_code
    expose :odometer_km
    expose :tank_capacity_liters
    expose :distance_since_last_refuel_km
    expose :confidence_level
    expose :product_type
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
    expose :consumption_per_100km, if: ->(instance, options) { options[:include_calculations] }

    # Anomalías
    expose :anomalies, if: ->(instance, options) { options[:include_anomalies] } do
      expose :exceeds_tank_capacity do |instance|
        instance.exceeds_tank_capacity?
      end
      expose :suspicious_location do |instance|
        instance.suspicious_location?
      end
    end

    # Datos raw solo para admins
    expose :raw_data, if: ->(instance, options) { options[:admin_view] }

    # Relaciones
    expose :vehicle, using: VehicleEntity, if: ->(instance, options) { options[:include_vehicle] }
  end
end
