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
    expose :features do |provider, _options|
      features = provider.integration_features.active.ordered
      Entities::MarketplaceFeatureEntity.represent(features)
    end
    expose :auth_info, if: { include_auth: true } do |provider, _options|
      schema = provider.integration_auth_schema
      next nil unless schema&.is_active?

      {
        fields_count: schema.auth_fields.is_a?(Array) ? schema.auth_fields.count : 0,
        required_fields: schema.required_fields.map { |f| f["name"] },
        has_examples: schema.example_credentials.present?
      }
    end
    expose :badge do |provider, _options|
      case provider.status
      when "beta" then "Beta"
      when "coming_soon" then "Próximamente"
      else nil
      end
    end
  end
end
