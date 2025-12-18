# app/api/entities/normalization_error_entity.rb
module Entities
  class NormalizationErrorEntity < Grape::Entity
    expose :raw_data_id do |error, _options|
      error[:raw_data].id
    end
    expose :external_id do |error, _options|
      error[:raw_data].external_id
    end
    expose :error_message do |error, _options|
      error[:message]
    end
    expose :error_type do |error, _options|
      error[:type] || "normalization_error"
    end
    expose :raw_data_preview do |error, _options|
      error[:raw_data].raw_data.first(3).to_h if error[:raw_data].raw_data.is_a?(Hash)
    end
    expose :occurred_at do |error, _options|
      error[:raw_data].normalized_at || error[:raw_data].created_at
    end
  end
end
