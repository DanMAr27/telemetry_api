# app/api/entities/feature_selection_entity.rb
module Entities
  class FeatureSelectionEntity < Grape::Entity
    expose :feature_key
    expose :feature_name
    expose :feature_description
    expose :is_active
    expose :display_order

    expose :enabled do |feature, options|
      config = options[:configuration]
      config ? config.feature_enabled?(feature.feature_key) : false
    end
  end
end
