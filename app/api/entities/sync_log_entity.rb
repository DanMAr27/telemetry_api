# app/api/entities/sync_log_entity.rb
module Entities
  class SyncLogEntity < Grape::Entity
    expose :id
    expose :tenant_integration_configuration_id
    expose :feature_key
    expose :status
    expose :started_at
    expose :finished_at
    expose :duration_seconds
    expose :records_fetched
    expose :records_processed
    expose :records_failed
    expose :error_message
    expose :created_at
    expose :provider_name, if: { include_provider: true } do |log, _options|
      log.tenant_integration_configuration.integration_provider.name
    end
    expose :status_badge do |log, _options|
      case log.status
      when "success" then "success"
      when "error" then "error"
      when "partial" then "warning"
      else "info"
      end
    end
  end
end
