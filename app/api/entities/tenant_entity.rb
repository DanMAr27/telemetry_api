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
           using: Entities::TenantIntegrationConfigurationSummaryEntity,
           if: { include_integrations: true }
    expose :is_active, if: { include_computed: true } do |tenant, _options|
      tenant.active?
    end
    expose :is_suspended, if: { include_computed: true } do |tenant, _options|
      tenant.suspended?
    end
    expose :is_trial, if: { include_computed: true } do |tenant, _options|
      tenant.trial?
    end
    expose :vehicles_count, if: { include_counts: true } do |tenant, _options|
      tenant.vehicles.count
    end
    expose :active_vehicles_count, if: { include_counts: true } do |tenant, _options|
      tenant.vehicles.active.count
    end
    expose :integrations_count, if: { include_counts: true } do |tenant, _options|
      tenant.tenant_integration_configurations.count
    end
    expose :active_integrations_count, if: { include_counts: true } do |tenant, _options|
      tenant.tenant_integration_configurations.active.count
    end
    expose :status_badge do |tenant, _options|
      case tenant.status
      when "active" then "success"
      when "trial" then "info"
      when "suspended" then "warning"
      else "default"
      end
    end
    expose :contact_info, if: { include_computed: true } do |tenant, _options|
      {
        email: tenant.email,
        name: tenant.name
      }
    end
    expose :last_activity, if: { include_computed: true } do |tenant, _options|
      last_sync = tenant.tenant_integration_configurations
        .maximum(:last_sync_at)

      {
        last_sync_at: last_sync,
        days_since_last_activity: last_sync ? (Time.current - last_sync).to_i / 86400 : nil
      }
    end
    expose :usage_summary, if: { include_usage: true } do |tenant, _options|
      {
        total_refuelings: VehicleRefueling.by_tenant(tenant.id).count,
        total_charges: VehicleElectricCharge.by_tenant(tenant.id).count,
        last_refueling_date: VehicleRefueling.by_tenant(tenant.id).maximum(:refueling_date),
        last_charge_date: VehicleElectricCharge.by_tenant(tenant.id).maximum(:charge_start_time)
      }
    end
    expose :active_providers, if: { include_computed: true } do |tenant, _options|
      tenant.tenant_integration_configurations.active
        .includes(:integration_provider)
        .map do |config|
          {
            id: config.integration_provider.id,
            name: config.integration_provider.name,
            slug: config.integration_provider.slug,
            logo_url: config.integration_provider.logo_url
          }
        end
    end
  end
end
