# app/api/entities/success_entity.rb
# Entity para respuestas de éxito estandarizadas
module Entities
  class SuccessEntity < Grape::Entity
    expose :success
    expose :message
    expose :data, if: ->(instance, _options) { instance.key?(:data) }
  end
end
