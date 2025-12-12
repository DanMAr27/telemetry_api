# app/api/entities/telemetry_normalization_error_entity.rb
module Entities
  class TelemetryNormalizationErrorEntity < Grape::Entity
    expose :id
    expose :telemetry_sync_log_id
    expose :error_type
    expose :error_message
    expose :provider_name
    expose :data_type
    expose :resolved
    expose :resolved_at
    expose :resolution_notes
    expose :created_at

    # Raw data solo para admins o vista detallada
    expose :raw_data, if: ->(instance, options) { options[:admin_view] || options[:detailed] }

    # Relaciones
    expose :sync_log, using: TelemetrySyncLogEntity, if: ->(instance, options) { options[:include_sync_log] }
  end
end
