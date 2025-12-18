# app/api/entities/integration_auth_schema_entity.rb
module Entities
  class IntegrationAuthSchemaEntity < Grape::Entity
    expose :id
    expose :integration_provider_id
    expose :auth_fields
    expose :example_credentials
    expose :is_active
    expose :created_at
    expose :updated_at
    # Relación opcional
    expose :integration_provider, using: Entities::IntegrationProviderEntity, if: { include_provider: true }
    expose :field_names, if: { include_computed: true } do |schema, _options|
      schema.field_names
    end
    expose :required_fields, if: { include_computed: true } do |schema, _options|
      schema.required_fields
    end
    expose :total_fields_count, if: { include_counts: true } do |schema, _options|
      schema.auth_fields.is_a?(Array) ? schema.auth_fields.count : 0
    end
  end
end
