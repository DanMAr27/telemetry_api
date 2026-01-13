# app/api/entities/global_statistics_entity.rb
module Entities
  class GlobalStatisticsEntity < Grape::Entity
    expose :period do |data|
      data[:period]
    end
    expose :filters_applied do |data|
      data[:filters_applied]
    end
    expose :executions do |data|
      data[:executions]
    end
    expose :raw_data do |data|
      data[:raw_data]
    end
    expose :by_feature do |data|
      data[:by_feature]
    end
    expose :by_status do |data|
      data[:by_status]
    end
    expose :trends, if: ->(data, _options) { data[:trends].present? } do |data|
      data[:trends]
    end
    expose :health_score do |data|
      data[:health_score]
    end
    expose :alerts do |data|
      data[:alerts]
    end
    expose :summary do |data|
      exec = data[:executions]
      raw = data[:raw_data]

      {
        total_executions: exec[:total],
        success_rate: exec[:success_rate],
        total_records_processed: exec[:total_records_processed],
        normalization_rate: raw[:normalization_rate],
        health_grade: data[:health_score][:grade],
        active_alerts: data[:alerts].count
      }
    end
  end
end
