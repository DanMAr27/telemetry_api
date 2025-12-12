# app/api/entities/vehicle_telemetry_config_entity.rb
module Entities
  class VehicleTelemetryConfigEntity < Grape::Entity
    expose :id
    expose :vehicle_id
    expose :telemetry_credential_id
    expose :external_device_id
    expose :sync_frequency
    expose :data_types
    expose :is_active
    expose :last_sync_at
    expose :created_at
    expose :updated_at

    # Información del proveedor
    expose :provider_name do |instance|
      instance.provider_name
    end

    # Relaciones opcionales
    expose :vehicle, using: VehicleEntity, if: ->(instance, options) { options[:include_vehicle] }
    expose :telemetry_credential, using: TelemetryCredentialEntity, if: ->(instance, options) { options[:include_credential] }

    # Helpers
    expose :syncs_refuels do |instance|
      instance.sync_refuels?
    end

    expose :syncs_charges do |instance|
      instance.sync_charges?
    end

    expose :syncs_odometer do |instance|
      instance.sync_odometer?
    end
  end
end
