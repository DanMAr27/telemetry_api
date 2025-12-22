# app/api/entities/connection_test_result_entity.rb
module Entities
  class ConnectionTestResultEntity < Grape::Entity
    expose :success
    expose :message
    expose :provider_name
    expose :tested_at do |result, _options|
      Time.current
    end
    expose :details, if: ->(result, _options) { result[:details].present? }
  end
end
