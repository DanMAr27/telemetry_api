# app/api/entities/integration_sync_execution_summary_entity.rb
module Entities
  class IntegrationSyncExecutionSummaryEntity < Grape::Entity
    expose :id
    expose :feature_key
    expose :status
    expose :started_at
    expose :duration_seconds
    expose :records_processed
    expose :records_failed
    expose :created_at
    expose :feature_name do |execution, _options|
      I18n.t("features.#{execution.feature_key}", default: execution.feature_key.humanize)
    end
    expose :stats do |execution, _options|
      {
        fetched: execution.records_fetched,
        processed: execution.records_processed,
        failed: execution.records_failed,
        skipped: execution.records_skipped,
        duplicates: execution.duplicate_records || 0
      }
    end
    expose :status_badge do |execution, _options|
      case execution.status
      when "running" then "info"
      when "completed" then execution.has_errors? ? "warning" : "success"
      when "failed" then "error"
      end
    end
  end
end
