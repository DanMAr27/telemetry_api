# app/api/entities/integration_category_entity.rb
module Entities
  class IntegrationCategoryEntity < Grape::Entity
    expose :id
    expose :name
    expose :slug
    expose :description
    expose :icon
    expose :display_order
    expose :is_active
    expose :created_at
    expose :updated_at
    expose :integration_providers, if: { include_providers: true } do |category, _options|
      category.integration_providers.map do |provider|
        {
          id: provider.id,
          name: provider.name,
          slug: provider.slug,
          description: provider.description,
          logo_url: provider.logo_url,
          status: provider.status,
          is_premium: provider.is_premium
        }
      end
    end

    expose :active_providers_count, if: { include_counts: true } do |category, _options|
      category.integration_providers.active.count
    end
  end
end
