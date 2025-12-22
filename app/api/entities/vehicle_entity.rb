# app/api/entities/vehicle_entity.rb
module Entities
  class VehicleEntity < Grape::Entity
    expose :id
    expose :name
    expose :license_plate
    expose :brand
    expose :model
    expose :fuel_type
    expose :is_electric
  end
end
