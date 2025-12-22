# app/api/entities/marketplace_category_entity.rb
module Entities
  class MarketplaceCategoryEntity < Grape::Entity
    expose :id
    expose :name
    expose :slug
    expose :description
    expose :icon
    expose :display_order
    expose :providers do |category, options|
      providers = category.integration_providers.for_marketplace
                    .includes(:integration_features, :integration_auth_schema)
      Entities::MarketplaceProviderEntity.represent(
        providers,
        include_category: false,
        include_features: options[:include_features],
        include_auth_info: options[:include_auth_info],
        include_stats: options[:include_stats]
      )
    end
    expose :providers_count do |category, _options|
      category.integration_providers.for_marketplace.count
    end
  end
end
