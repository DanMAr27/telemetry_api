# app/api/entities/telemetry_sync_log_entity.rb
module Entities
  class TelemetrySyncLogEntity < Grape::Entity
    expose :id
    expose :telemetry_credential_id
    expose :vehicle_id
    expose :sync_type
    expose :status
    expose :records_processed
    expose :records_created
    expose :records_updated
    expose :records_skipped
    expose :error_message
    expose :started_at
    expose :completed_at
    expose :created_at

    # Métricas
    expose :duration_seconds do |instance|
      instance.duration_seconds
    end

    expose :success_rate_percent do |instance|
      instance.success_rate_percent
    end

    expose :has_errors do |instance|
      instance.has_errors?
    end

    expose :error_count do |instance|
      instance.error_count
    end

    # Relaciones
    expose :telemetry_credential, using: TelemetryCredentialEntity, if: ->(instance, options) { options[:include_credential] }
    expose :vehicle, using: VehicleEntity, if: ->(instance, options) { options[:include_vehicle] }
    expose :errors, using: TelemetryNormalizationErrorEntity, if: ->(instance, options) { options[:include_errors] }

    # Error details solo para admins
    expose :error_details, if: ->(instance, options) { options[:admin_view] }
  end
end
