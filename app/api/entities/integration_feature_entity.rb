# app/api/entities/integration_feature_entity.rb
module Entities
  class IntegrationFeatureEntity < Grape::Entity
    expose :id
    expose :integration_provider_id
    expose :feature_key
    expose :feature_name
    expose :feature_description
    expose :display_order
    expose :is_active
    expose :created_at
    expose :updated_at
    expose :integration_provider, if: { include_provider: true } do |feature, _options|
      {
        id: feature.integration_provider.id,
        name: feature.integration_provider.name,
        slug: feature.integration_provider.slug,
        logo_url: feature.integration_provider.logo_url
      }
    end

    expose :available, if: { include_computed: true } do |feature, _options|
      feature.available?
    end
  end
end
