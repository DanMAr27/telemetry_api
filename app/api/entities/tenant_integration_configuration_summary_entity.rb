# app/api/entities/tenant_integration_configuration_summary_entity.rb
module Entities
  class TenantIntegrationConfigurationSummaryEntity < Grape::Entity
    expose :id
    expose :is_active
    expose :activated_at
    expose :sync_frequency
    expose :sync_hour
    expose :last_sync_at
    expose :last_sync_status
    expose :created_at
    expose :provider do |config, _options|
      {
        id: config.integration_provider.id,
        name: config.integration_provider.name,
        slug: config.integration_provider.slug,
        logo_url: config.integration_provider.logo_url
      }
    end
    expose :enabled_features_count do |config, _options|
      config.enabled_features.size
    end
    expose :status_badge do |config, _options|
      if config.is_active
        config.has_error? ? "active_with_errors" : "active"
      else
        "inactive"
      end
    end
    expose :sync_schedule do |config, _options|
      config.sync_schedule_description
    end
  end
end
