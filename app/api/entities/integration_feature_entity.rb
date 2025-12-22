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
    expose :integration_provider, using: Entities::IntegrationProviderEntity, if: { include_provider: true }
    expose :available, if: { include_computed: true } do |feature, _options|
      feature.available?
    end
  end
end
