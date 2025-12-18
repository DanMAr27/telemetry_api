# app/api/entities/sync_statistics_entity.rb
module Entities
  class SyncStatisticsEntity < Grape::Entity
    expose :total_executions
    expose :completed_executions
    expose :failed_executions
    expose :running_executions

    expose :total_raw_records
    expose :pending_records
    expose :normalized_records
    expose :failed_records
    expose :duplicate_records

    expose :total_refuelings
    expose :total_electric_charges

    expose :last_sync_at
    expose :next_sync_at

    expose :success_rate do |stats, _options|
      return 0 if stats[:total_executions].zero?
      ((stats[:completed_executions].to_f / stats[:total_executions]) * 100).round(2)
    end

    expose :executions_by_feature do |stats, _options|
      stats[:by_feature] || {}
    end

    expose :executions_by_status do |stats, _options|
      stats[:by_status] || {}
    end
  end
end
