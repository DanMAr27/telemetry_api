# app/api/entities/success_entity.rb
module Entities
  class SuccessEntity < Grape::Entity
    expose :success
    expose :message
    expose :data, if: ->(instance, _options) { instance.key?(:data) }
  end
end
