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
    expose :integration_provider, if: { include_provider: true } do |schema, _options|
      {
        id: schema.integration_provider.id,
        name: schema.integration_provider.name,
        slug: schema.integration_provider.slug
      }
    end
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
