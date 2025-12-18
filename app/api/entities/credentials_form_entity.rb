# app/api/entities/credentials_form_entity.rb
# Entity para devolver el formulario de credenciales dinámico
module Entities
  class CredentialsFormEntity < Grape::Entity
    expose :provider_id do |provider, _options|
      provider.id
    end

    expose :provider_name do |provider, _options|
      provider.name
    end

    expose :provider_slug do |provider, _options|
      provider.slug
    end

    expose :fields do |provider, _options|
      schema = provider.integration_auth_schema
      next [] unless schema

      schema.auth_fields.map do |field|
        {
          name: field["name"],
          type: field["type"],
          label: field["label"],
          placeholder: field["placeholder"],
          required: field["required"] || false,
          options: field["options"] || []
        }
      end
    end

    expose :example_credentials do |provider, _options|
      schema = provider.integration_auth_schema
      schema&.example_credentials || {}
    end
  end
end
