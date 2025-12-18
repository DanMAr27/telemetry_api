# app/api/entities/error_entity.rb
module Entities
  class ErrorEntity < Grape::Entity
    expose :error
    expose :message
    expose :details, if: { include_details: true }
    expose :field, if: ->(instance, _options) { instance.key?(:field) }
  end
end
