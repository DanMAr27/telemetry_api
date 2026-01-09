# app/api/entities/integration_sync_execution_entity.rb
module Entities
  class IntegrationSyncExecutionEntity < Grape::Entity
    expose :id
    expose :tenant_integration_configuration_id
    expose :feature_key
    expose :trigger_type
    expose :status
    expose :started_at
    expose :finished_at
    expose :duration_seconds
    expose :records_fetched
    expose :records_processed
    expose :records_failed
    expose :records_skipped
    expose :duplicate_records
    expose :duplicate_external_ids
    expose :error_message
    expose :metadata
    expose :created_at
    expose :updated_at
    expose :provider_info, unless: { include_provider: true } do |execution, _options|
      {
        id: execution.integration_provider.id,
        name: execution.integration_provider.name,
        slug: execution.integration_provider.slug
      }
    end
    expose :tenant_integration_configuration,
           using: Entities::TenantIntegrationConfigurationEntity,
           if: { include_configuration: true }
    expose :success_rate, if: { include_computed: true } do |execution, _options|
      execution.success_rate
    end
    expose :has_errors, if: { include_computed: true } do |execution, _options|
      execution.has_errors?
    end
    expose :has_duplicates, if: { include_computed: true } do |execution, _options|
      execution.has_duplicates?
    end
    expose :is_running, if: { include_computed: true } do |execution, _options|
      execution.running?
    end
    expose :is_completed, if: { include_computed: true } do |execution, _options|
      execution.completed?
    end

    expose :description, if: { include_computed: true } do |execution, _options|
      execution.description
    end
    expose :duration_formatted, if: { include_computed: true } do |execution, _options|
      next nil unless execution.duration_seconds
      minutes = execution.duration_seconds / 60
      seconds = execution.duration_seconds % 60
      "#{minutes}m #{seconds}s"
    end
    expose :status_badge do |execution, _options|
      case execution.status
      when "running" then "info"
      when "completed" then execution.has_errors? ? "warning" : "success"
      when "failed" then "error"
      else "default"
      end
    end
  end
end
