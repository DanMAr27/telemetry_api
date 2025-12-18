# app/api/entities/tenant_summary_entity.rb
module Entities
  class TenantSummaryEntity < Grape::Entity
    expose :id
    expose :name
    expose :slug
    expose :email
    expose :status
    expose :created_at
    expose :status_badge do |tenant, _options|
      case tenant.status
      when "active" then "success"
      when "trial" then "info"
      when "suspended" then "warning"
      else "default"
      end
    end
    expose :active_integrations_count do |tenant, _options|
      tenant.tenant_integration_configurations.active.count
    end
    expose :vehicles_count do |tenant, _options|
      tenant.vehicles.count
    end
    expose :last_sync_at do |tenant, _options|
      tenant.tenant_integration_configurations.maximum(:last_sync_at)
    end
  end
end
