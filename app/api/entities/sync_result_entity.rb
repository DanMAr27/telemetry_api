# app/api/entities/sync_result_entity.rb
module Entities
  class SyncResultEntity < Grape::Entity
    expose :success
    expose :execution_id
    expose :feature_key
    expose :message
    expose :statistics do |result, _options|
      {
        records_fetched: result[:records_fetched] || 0,
        records_processed: result[:records_processed] || 0,
        records_failed: result[:records_failed] || 0,
        records_skipped: result[:records_skipped] || 0
      }
    end
    expose :duration_seconds
    expose :started_at
    expose :finished_at
    expose :errors, if: ->(result, _options) { result[:errors].present? }
    expose :warnings, if: ->(result, _options) { result[:warnings].present? } do |result, _options|
      result[:warnings] || []
    end
  end
end
