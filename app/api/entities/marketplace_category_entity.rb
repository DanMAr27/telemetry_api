# app/api/entities/marketplace_category_entity.rb
module Entities
  class MarketplaceCategoryEntity < Grape::Entity
    expose :id
    expose :name
    expose :slug
    expose :description
    expose :icon
    expose :display_order
    # Solo providers disponibles para marketplace
    expose :providers do |category, _options|
      providers = category.integration_providers.for_marketplace.includes(:integration_features, :integration_auth_schema)
      Entities::MarketplaceProviderEntity.represent(providers)
    end
    expose :providers_count do |category, _options|
      category.integration_providers.for_marketplace.count
    end
  end
end
