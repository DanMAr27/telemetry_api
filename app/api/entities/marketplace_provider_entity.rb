# app/api/entities/marketplace_provider_entity.rb
module Entities
  class MarketplaceProviderEntity < Grape::Entity
    expose :id
    expose :name
    expose :slug
    expose :description
    expose :logo_url
    expose :website_url
    expose :status
    expose :is_premium

    expose :category, if: { include_category: true } do |provider, _options|
      {
        id: provider.integration_category.id,
        name: provider.integration_category.name,
        slug: provider.integration_category.slug,
        icon: provider.integration_category.icon
      }
    end

    expose :features do |provider, _options|
      provider.integration_features.active.ordered.map do |feature|
        {
          key: feature.feature_key,
          name: feature.feature_name,
          description: feature.feature_description,
          # Now this works because it's an instance method
          icon: get_feature_icon(feature.feature_key)
        }
      end
    end

    expose :features_count do |provider, _options|
      provider.integration_features.active.count
    end

    expose :authentication_info, if: { include_auth: true } do |provider, _options|
      schema = provider.integration_auth_schema
      next nil unless schema&.is_active

      {
        has_auth_schema: true,
        required_fields_count: schema.required_fields.count,
        field_types: schema.auth_fields.map { |f| f["type"] }.uniq,
        supports_test_connection: true
      }
    end

    expose :availability do |provider, _options|
      {
        is_available: provider.available?,
        is_production_ready: provider.ready_for_production?,
        # These also work now as instance methods
        status_label: status_label(provider.status),
        status_badge_color: status_badge_color(provider.status)
      }
    end

    # ... rest of your exposures ...

    private # Good practice to keep helpers private

    def status_label(status)
      {
        "active" => "Disponible",
        "beta" => "Beta",
        "coming_soon" => "Próximamente",
        "deprecated" => "Obsoleto"
      }[status] || "Desconocido"
    end

    def status_badge_color(status)
      {
        "active" => "success",
        "beta" => "warning",
        "coming_soon" => "info",
        "deprecated" => "error"
      }[status] || "default"
    end

    def get_feature_icon(feature_key)
      {
        "fuel" => "local_gas_station",
        "battery" => "battery_charging_full",
        "trips" => "route",
        "real_time_location" => "location_on",
        "odometer" => "speed",
        "diagnostics" => "build"
      }[feature_key] || "check_circle"
    end
  end
end
