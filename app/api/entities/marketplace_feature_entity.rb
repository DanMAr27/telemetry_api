# app/api/entities/marketplace_feature_entity.rb
module Entities
  class MarketplaceFeatureEntity < Grape::Entity
    expose :feature_key
    expose :feature_name
    expose :feature_description
  end
end
