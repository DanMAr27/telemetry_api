# app/api/entities/integration_provider_entity.rb
module Entities
  class IntegrationProviderEntity < Grape::Entity
    expose :id
    expose :integration_category_id
    expose :name
    expose :slug
    expose :api_base_url
    expose :description
    expose :logo_url
    expose :website_url
    expose :status
    expose :is_premium
    expose :display_order
    expose :is_active
    expose :created_at
    expose :updated_at
    expose :integration_category, using: Entities::IntegrationCategoryEntity, if: { include_category: true }
    expose :integration_auth_schema, using: Entities::IntegrationAuthSchemaEntity, if: { include_auth_schema: true }
    expose :integration_features, if: { include_features: true } do |provider, _options|
      provider.integration_features.map do |feature|
        {
          id: feature.id,
          feature_key: feature.feature_key,
          feature_name: feature.feature_name,
          feature_description: feature.feature_description,
          display_order: feature.display_order,
          is_active: feature.is_active
        }
      end
    end
    expose :available, if: { include_computed: true } do |provider, _options|
      provider.available?
    end
    expose :ready_for_production, if: { include_computed: true } do |provider, _options|
      provider.ready_for_production?
    end
    expose :active_features_count, if: { include_counts: true } do |provider, _options|
      provider.integration_features.active.count
    end
  end
end
