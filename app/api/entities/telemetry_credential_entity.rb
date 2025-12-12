# app/api/entities/telemetry_credential_entity.rb
module Entities
  class TelemetryCredentialEntity < Grape::Entity
    expose :id
    expose :company_id
    expose :telemetry_provider_id
    expose :is_active
    expose :last_sync_at
    expose :last_successful_sync_at
    expose :created_at
    expose :updated_at

    # Relaciones
    expose :telemetry_provider, using: TelemetryProviderEntity, if: ->(instance, options) { options[:include_provider] }

    # Exponer schema de configuración del proveedor (para que frontend sepa qué campos mostrar)
    expose :configuration_schema, if: ->(instance, options) { options[:include_config_schema] } do |instance|
      instance.telemetry_provider.configuration_schema
    end

    # Mostrar qué campos están configurados (sin exponer valores)
    expose :configured_fields, if: ->(instance, options) { options[:include_config_schema] } do |instance|
      credentials = instance.credentials_hash
      schema_fields = instance.telemetry_provider.configuration_schema.fetch("fields", [])

      schema_fields.map do |field|
        {
          name: field["name"],
          label: field["label"],
          configured: credentials[field["name"]].present?
        }
      end
    end

    # Nunca exponer las credenciales reales por seguridad
    # Solo indicar si están configuradas
    expose :has_credentials do |instance|
      instance.credentials.present?
    end

    # Estadísticas
    expose :vehicles_count, if: ->(instance, options) { options[:include_stats] } do |instance|
      instance.vehicles.count
    end

    expose :active_vehicles_count, if: ->(instance, options) { options[:include_stats] } do |instance|
      instance.vehicle_telemetry_configs.active.count
    end
  end
end
