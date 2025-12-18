# app/api/entities/tenant_integration_configuration_entity.rb
module Entities
  class TenantIntegrationConfigurationEntity < Grape::Entity
    expose :id
    expose :tenant_id
    expose :integration_provider_id
    # NO exponemos credentials por seguridad
    # expose :encrypted_credentials # NUNCA exponer
    expose :is_active
    expose :activated_at
    expose :sync_frequency
    expose :sync_hour
    expose :sync_day_of_week
    expose :sync_day_of_month
    expose :enabled_features
    expose :sync_config
    expose :last_sync_at
    expose :last_sync_status
    expose :last_sync_error
    expose :metadata
    expose :created_at
    expose :updated_at
    expose :tenant, using: Entities::TenantEntity, if: { include_tenant: true }
    expose :integration_provider,
           using: Entities::IntegrationProviderEntity,
           if: { include_provider: true }
    expose :provider_info, unless: { include_provider: true } do |config, _options|
      {
        id: config.integration_provider.id,
        name: config.integration_provider.name,
        slug: config.integration_provider.slug,
        logo_url: config.integration_provider.logo_url
      }
    end
    expose :has_credentials, if: { include_computed: true } do |config, _options|
      config.credentials.present?
    end
    expose :has_error, if: { include_computed: true } do |config, _options|
      config.has_error?
    end
    expose :sync_schedule_description, if: { include_computed: true } do |config, _options|
      config.sync_schedule_description
    end
    expose :next_sync_at, if: { include_computed: true } do |config, _options|
      config.calculate_next_sync_at if config.is_active
    end
    expose :available_features, if: { include_features: true } do |config, _options|
      config.available_features.map do |feature|
        {
          feature_key: feature.feature_key,
          feature_name: feature.feature_name,
          feature_description: feature.feature_description
        }
      end
    end
    expose :required_credentials, if: { include_auth_info: true } do |config, _options|
      schema = config.integration_provider.integration_auth_schema
      next [] unless schema

      schema.auth_fields.map do |field|
        {
          name: field["name"],
          label: field["label"],
          type: field["type"],
          required: field["required"],
          placeholder: field["placeholder"]
        }
      end
    end
  end
end
