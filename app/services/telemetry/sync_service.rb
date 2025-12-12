# app/services/telemetry/sync_service.rb
module Telemetry
  class SyncService
    attr_reader :credential, :sync_log, :stats

    def initialize(telemetry_credential)
      @credential = telemetry_credential
      @sync_log = nil
      @stats = {
        processed: 0,
        created: 0,
        updated: 0,
        skipped: 0,
        errors: []
      }
    end

    # Sincronizar repostajes
    def sync_refuels(vehicle_id: nil, from_date: nil, to_date: nil)
      execute_sync(sync_type: "refuels", vehicle_id: vehicle_id) do
        from_date ||= credential.from_date_for_sync
        to_date ||= Time.current

        connector = build_connector
        normalizer = build_normalizer

        # Obtener datos raw de Geotab
        raw_fillups = connector.fetch_fillups(from_date: from_date, to_date: to_date)

        # Procesar cada repostaje
        raw_fillups.each do |raw_fillup|
          process_refuel(raw_fillup, normalizer)
        end
      end
    end

    # Sincronizar cargas eléctricas
    def sync_charges(vehicle_id: nil, from_date: nil, to_date: nil)
      execute_sync(sync_type: "charges", vehicle_id: vehicle_id) do
        from_date ||= credential.from_date_for_sync
        to_date ||= Time.current

        connector = build_connector
        normalizer = build_normalizer

        # Obtener datos raw de Geotab
        raw_charges = connector.fetch_charge_events(from_date: from_date, to_date: to_date)

        # Procesar cada carga
        raw_charges.each do |raw_charge|
          process_charge(raw_charge, normalizer)
        end
      end
    end

    # Sincronización completa
    def sync_all(from_date: nil, to_date: nil)
      results = {}

      results[:refuels] = sync_refuels(from_date: from_date, to_date: to_date)
      results[:charges] = sync_charges(from_date: from_date, to_date: to_date)

      results
    end

    private

    def execute_sync(sync_type:, vehicle_id: nil)
      @sync_log = create_sync_log(sync_type: sync_type, vehicle_id: vehicle_id)
      started_at = Time.current

      begin
        yield # Ejecuta el bloque de sincronización

        # Actualizar log como exitoso
        status = @stats[:errors].any? ? "partial" : "success"
        complete_sync_log(status: status, started_at: started_at)

        # Actualizar timestamp de la credencial
        credential.update_sync_timestamp!(successful: status == "success")

        build_result(success: true)
      rescue Connectors::GeotabConnector::GeotabError => e
        complete_sync_log(status: "error", started_at: started_at, error: e)
        build_result(success: false, error: e.message)
      rescue StandardError => e
        complete_sync_log(status: "error", started_at: started_at, error: e)
        build_result(success: false, error: e.message)
      end
    end

    def process_refuel(raw_fillup, normalizer)
      @stats[:processed] += 1

      # Obtener el vehicle_id del dispositivo
      vehicle = find_vehicle_by_device(raw_fillup.dig("device", "id"))

      unless vehicle
        @stats[:skipped] += 1
        log_error(
          raw_data: raw_fillup,
          error_type: "mapping_error",
          error_message: "Vehicle not found for device #{raw_fillup.dig('device', 'id')}"
        )
        return
      end

      # Normalizar datos
      normalized = normalizer.normalize_refuel(raw_fillup, vehicle.id)

      # Validar
      validation_errors = normalizer.validate_refuel(normalized)
      if validation_errors.any?
        @stats[:skipped] += 1
        log_error(
          raw_data: raw_fillup,
          error_type: "validation_error",
          error_message: validation_errors.join(", ")
        )
        return
      end

      # Crear o actualizar
      refuel = Refuel.find_or_initialize_by(
        vehicle_id: normalized[:vehicle_id],
        external_id: normalized[:external_id],
        provider_name: normalized[:provider_name]
      )

      if refuel.new_record?
        refuel.assign_attributes(normalized)
        refuel.save!
        @stats[:created] += 1
      else
        refuel.update!(normalized)
        @stats[:updated] += 1
      end

    rescue StandardError => e
      @stats[:skipped] += 1
      log_error(
        raw_data: raw_fillup,
        error_type: "data_format_error",
        error_message: e.message
      )
    end

    def process_charge(raw_charge, normalizer)
      @stats[:processed] += 1

      # Obtener el vehicle_id del dispositivo
      vehicle = find_vehicle_by_device(raw_charge.dig("device", "id"))

      unless vehicle
        @stats[:skipped] += 1
        log_error(
          raw_data: raw_charge,
          error_type: "mapping_error",
          error_message: "Vehicle not found for device #{raw_charge.dig('device', 'id')}"
        )
        return
      end

      # Normalizar datos
      normalized = normalizer.normalize_charge_event(raw_charge, vehicle.id)

      # Validar
      validation_errors = normalizer.validate_charge_event(normalized)
      if validation_errors.any?
        @stats[:skipped] += 1
        log_error(
          raw_data: raw_charge,
          error_type: "validation_error",
          error_message: validation_errors.join(", ")
        )
        return
      end

      # Crear o actualizar
      charge = ElectricCharge.find_or_initialize_by(
        vehicle_id: normalized[:vehicle_id],
        external_id: normalized[:external_id],
        provider_name: normalized[:provider_name]
      )

      if charge.new_record?
        charge.assign_attributes(normalized)
        charge.save!
        @stats[:created] += 1
      else
        charge.update!(normalized)
        @stats[:updated] += 1
      end

    rescue StandardError => e
      @stats[:skipped] += 1
      log_error(
        raw_data: raw_charge,
        error_type: "data_format_error",
        error_message: e.message
      )
    end

    def find_vehicle_by_device(device_id)
      return nil if device_id.blank?

      config = VehicleTelemetryConfig
        .where(telemetry_credential_id: credential.id)
        .find_by(external_device_id: device_id)

      config&.vehicle
    end

    def build_connector
      provider_slug = credential.provider_name

      # Usar el registry en lugar de case/when
      Telemetry::ProviderRegistry.build_connector(
        provider_slug,
        credential.credentials_hash
      )
    rescue Telemetry::ProviderRegistry::UnknownProviderError => e
      raise "Provider '#{provider_slug}' not implemented: #{e.message}"
    end

    def build_normalizer
      provider_slug = credential.provider_name

      # Usar el registry en lugar de case/when
      Telemetry::ProviderRegistry.build_normalizer(provider_slug)
    rescue Telemetry::ProviderRegistry::UnknownProviderError => e
      raise "Provider '#{provider_slug}' not implemented: #{e.message}"
    end

    def create_sync_log(sync_type:, vehicle_id:)
      TelemetrySyncLog.create!(
        telemetry_credential_id: credential.id,
        vehicle_id: vehicle_id,
        sync_type: sync_type,
        status: "pending",
        started_at: Time.current
      )
    end

    def complete_sync_log(status:, started_at:, error: nil)
      @sync_log.update!(
        status: status,
        records_processed: @stats[:processed],
        records_created: @stats[:created],
        records_updated: @stats[:updated],
        records_skipped: @stats[:skipped],
        error_message: error&.message,
        error_details: error ? { backtrace: error.backtrace.first(5) } : {},
        completed_at: Time.current
      )
    end

    def log_error(raw_data:, error_type:, error_message:)
      @stats[:errors] << {
        error_type: error_type,
        error_message: error_message,
        raw_data: raw_data
      }

      TelemetryNormalizationError.create!(
        telemetry_sync_log_id: @sync_log.id,
        error_type: error_type,
        error_message: error_message,
        raw_data: raw_data,
        provider_name: credential.provider_name,
        data_type: @sync_log.sync_type
      )
    end

    def build_result(success:, error: nil)
      {
        success: success,
        sync_log_id: @sync_log.id,
        stats: {
          processed: @stats[:processed],
          created: @stats[:created],
          updated: @stats[:updated],
          skipped: @stats[:skipped],
          error_count: @stats[:errors].count
        },
        error: error
      }
    end
  end
end
