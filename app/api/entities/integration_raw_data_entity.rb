# app/api/entities/integration_raw_data_entity.rb
module Entities
  class IntegrationRawDataEntity < Grape::Entity
    expose :id
    expose :integration_sync_execution_id
    expose :tenant_integration_configuration_id
    expose :provider_slug
    expose :feature_key
    expose :external_id
    expose :raw_data, if: { include_raw_data: true }
    expose :processing_status
    expose :normalized_record_type
    expose :normalized_record_id
    expose :normalization_error
    expose :normalized_at
    expose :created_at
    expose :integration_sync_execution,
           using: Entities::IntegrationSyncExecutionSummaryEntity,
           if: { include_execution: true }
    expose :is_pending, if: { include_computed: true } do |raw_data, _options|
      raw_data.pending?
    end
    expose :is_normalized, if: { include_computed: true } do |raw_data, _options|
      raw_data.normalized?
    end
    expose :is_failed, if: { include_computed: true } do |raw_data, _options|
      raw_data.failed?
    end
    expose :is_duplicate, if: { include_computed: true } do |raw_data, _options|
      raw_data.duplicate?
    end
    expose :raw_data_preview, unless: { include_raw_data: true } do |raw_data, _options|
      return nil unless raw_data.raw_data.is_a?(Hash)
      raw_data.raw_data.first(3).to_h
    end
    expose :normalized_record_link, if: { include_computed: true } do |raw_data, _options|
      next nil unless raw_data.normalized_record_type && raw_data.normalized_record_id

      {
        type: raw_data.normalized_record_type,
        id: raw_data.normalized_record_id,
        path: case raw_data.normalized_record_type
              when "VehicleRefueling" then "/vehicles/refuelings/#{raw_data.normalized_record_id}"
              when "VehicleElectricCharge" then "/vehicles/electric_charges/#{raw_data.normalized_record_id}"
              end
      }
    end
    expose :status_badge do |raw_data, _options|
      case raw_data.processing_status
      when "pending" then "info"
      when "normalized" then "success"
      when "failed" then "error"
      when "duplicate" then "warning"
      else "default"
      end
    end
    expose :available_actions do |obj, opts|
      Entities::IntegrationRawDataEntity.build_available_actions(obj, opts)
    end

    def self.build_available_actions(obj, _opts = {})
      actions = []

      case obj.processing_status
      when "failed"
        actions << { id: "retry", label: "Reintentar", method: "POST", url: "/api/v1/raw_data/#{obj.id}/retry" }
      when "duplicate"
        actions << { id: "ignore", label: "Ignorar", method: "POST", url: "/api/v1/raw_data/#{obj.id}/ignore" }
      end

      # Acciones comunes
      actions << { id: "view_raw", label: "Ver Raw JSON", method: "GET", url: "/api/v1/raw_data/#{obj.id}" }

      actions
    end
  end
end
