# app/api/entities/tenant_entity.rb
module Entities
  class TenantEntity < Grape::Entity
    expose :id
    expose :name
    expose :slug
    expose :email
    expose :status
    expose :settings
    expose :created_at
    expose :updated_at
    expose :tenant_integration_configurations,
           using: Entities::TenantIntegrationConfigurationEntity,
           if: { include_integrations: true }
    expose :is_active, if: { include_computed: true } do |tenant, _options|
      tenant.active?
    end
    expose :integrations_count, if: { include_counts: true } do |tenant, _options|
      tenant.tenant_integration_configurations.count
    end
    expose :active_integrations_count, if: { include_counts: true } do |tenant, _options|
      tenant.tenant_integration_configurations.active.count
    end
  end
end
