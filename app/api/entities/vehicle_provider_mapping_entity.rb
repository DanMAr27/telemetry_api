# app/api/entities/vehicle_provider_mapping_entity.rb
module Entities
  class VehicleProviderMappingEntity < Grape::Entity
    expose :id
    expose :vehicle_id
    expose :tenant_integration_configuration_id
    expose :external_vehicle_id
    expose :external_vehicle_name
    expose :is_active
    expose :mapped_at
    expose :last_sync_at
    expose :external_metadata
    expose :created_at
    expose :updated_at
    expose :vehicle_info do |mapping, _options|
      {
        id: mapping.vehicle.id,
        name: mapping.vehicle.name,
        license_plate: mapping.vehicle.license_plate,
        brand: mapping.vehicle.brand,
        model: mapping.vehicle.model
      }
    end
    expose :provider_info do |mapping, _options|
      {
        id: mapping.integration_provider.id,
        name: mapping.integration_provider.name,
        slug: mapping.integration_provider.slug
      }
    end
    expose :description do |mapping, _options|
      mapping.description
    end
  end
end
