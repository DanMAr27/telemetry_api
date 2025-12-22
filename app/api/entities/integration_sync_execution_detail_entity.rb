# app/api/entities/integration_sync_execution_detail_entity.rb
module Entities
  class IntegrationSyncExecutionDetailEntity < Grape::Entity
    expose :id

    expose :integration do |data|
      data[:integration]
    end

    expose :execution do |data|
      data[:execution]
    end

    expose :statistics do |data|
      data[:statistics]
    end

    expose :metadata do |data|
      data[:metadata]
    end

    expose :timeline, if: ->(data, opts) { data[:timeline].present? } do |data|
      data[:timeline]
    end

    expose :raw_data_sample, if: ->(data, opts) { data[:raw_data_sample].present? } do |data|
      data[:raw_data_sample]
    end

    expose :errors_summary, if: ->(data, opts) { data[:errors_summary].present? } do |data|
      data[:errors_summary]
    end

    expose :related_data do |data|
      data[:related_data]
    end
  end
end
