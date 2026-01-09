# app/api/entities/marketplace_provider_entity.rb
module Entities
  class MarketplaceProviderEntity < Grape::Entity
    FEATURE_ICONS = {
      "fuel" => "local_gas_station",
      "battery" => "battery_charging_full",
      "trips" => "route",
      "real_time_location" => "location_on",
      "odometer" => "speed",
      "diagnostics" => "build"
    }.freeze

    STATUS_LABELS = {
      "active" => "Disponible",
      "beta" => "Beta",
      "coming_soon" => "Próximamente",
      "deprecated" => "Obsoleto"
    }.freeze

    STATUS_BADGE_COLORS = {
      "active" => "success",
      "beta" => "warning",
      "coming_soon" => "info",
      "deprecated" => "error"
    }.freeze

    expose :id
    expose :name
    expose :slug
    expose :description
    expose :logo_url
    expose :website_url
    expose :status
    expose :is_premium
    expose :category, if: ->(provider, options) { options[:include_category] } do |provider, _options|
      {
        id: provider.integration_category.id,
        name: provider.integration_category.name,
        slug: provider.integration_category.slug,
        icon: provider.integration_category.icon
      }
    end
    expose :features, if: ->(provider, options) { options[:include_features] } do |provider, _options|
      provider.integration_features.active.ordered.map do |feature|
        {
          key: feature.feature_key,
          name: feature.feature_name,
          description: feature.feature_description,
          icon: FEATURE_ICONS[feature.feature_key] || "check_circle"  # ✅ Uso de constante
        }
      end
    end
    expose :features_count do |provider, _options|
      provider.integration_features.active.count
    end
    expose :authentication_info, if: ->(provider, options) { options[:include_auth_info] } do |provider, _options|
      schema = provider.integration_auth_schema
      next nil unless schema&.is_active

      {
        has_auth_schema: true,
        required_fields_count: schema.required_fields.count,
        field_types: schema.auth_fields.map { |f| f["type"] }.uniq,
        example_provided: schema.example_credentials.present?,
        fields_preview: schema.auth_fields.first(3).map do |field|
          {
            name: field["name"],
            type: field["type"],
            label: field["label"],
            required: field["required"]
          }
        end
      }
    end
    expose :usage_stats, if: ->(provider, options) { options[:include_stats] } do |provider, _options|
      executions = IntegrationSyncExecution
        .joins(:tenant_integration_configuration)
        .where(tenant_integration_configurations: { integration_provider_id: provider.id })
        .where("started_at >= ?", 30.days.ago)

      total = executions.count
      success_rate = if total.zero?
        0
      else
        completed = executions.completed.count
        ((completed.to_f / total) * 100).round(2)
      end

      {
        total_configurations: provider.tenant_integration_configurations.count,
        active_configurations: provider.tenant_integration_configurations.active.count,
        total_syncs_last_30d: total,
        success_rate_last_30d: success_rate
      }
    end
    expose :availability do |provider, _options|
      {
        is_available: provider.available?,
        is_production_ready: provider.ready_for_production?,
        status_label: STATUS_LABELS[provider.status] || "Desconocido",
        status_badge_color: STATUS_BADGE_COLORS[provider.status] || "default"
      }
    end
  end
end
