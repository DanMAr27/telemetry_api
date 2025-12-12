# app/api/entities/telemetry_provider_entity.rb
module Entities
  class TelemetryProviderEntity < Grape::Entity
    expose :id
    expose :name
    expose :slug
    expose :description
    expose :is_active
    expose :created_at
    expose :updated_at

    # Exponer solo en vistas detalladas

    expose :api_base_url, if: ->(instance, options) { options[:detailed] }
    expose :configuration_schema, if: ->(instance, options) { options[:detailed] }
  end
end
