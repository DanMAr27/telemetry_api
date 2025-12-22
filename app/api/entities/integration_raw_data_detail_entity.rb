# app/api/entities/integration_raw_data_detail_entity.rb
module Entities
  class IntegrationRawDataDetailEntity < Grape::Entity
    # Información básica
    expose :id
    expose :integration_sync_execution_id
    expose :tenant_integration_configuration_id

    expose :provider_slug
    expose :feature_key
    expose :external_id

    # Estado y procesamiento
    expose :processing_status
    expose :normalization_error
    expose :normalized_at
    expose :created_at
    expose :updated_at

    # Raw data completo
    expose :raw_data

    # Metadata extendida
    expose :metadata do |obj|
      base = obj.metadata || {}

      base.merge({
        retry_count: obj.retry_count || 0,
        last_retry_at: obj.last_retry_at,
        # Llamada corregida indicando la clase:
        error_type: Entities::IntegrationRawDataDetailEntity.detect_error_type(obj),
        processing_duration_ms: Entities::IntegrationRawDataDetailEntity.calculate_duration(obj),
        normalizer_class: "#{obj.provider_slug.classify}::#{obj.feature_key.classify}Normalizer"
      })
    end

    # Sync execution completa
    expose :sync_execution do |obj|
      next nil unless obj.integration_sync_execution

      exec = obj.integration_sync_execution
      {
        id: exec.id,
        feature_key: exec.feature_key,
        started_at: exec.started_at,
        finished_at: exec.finished_at,
        status: exec.status,
        records_fetched: exec.records_fetched,
        records_processed: exec.records_processed,
        records_failed: exec.records_failed,
        url: "/api/v1/integrations/#{obj.tenant_integration_configuration_id}/sync-executions/#{exec.id}"
      }
    end

    # Configuración
    expose :configuration do |obj|
      next nil unless obj.tenant_integration_configuration

      config = obj.tenant_integration_configuration
      {
        id: config.id,
        provider: {
          name: config.integration_provider.name,
          slug: config.integration_provider.slug,
          logo_url: config.integration_provider.logo_url
        },
        tenant: {
          id: config.tenant_id,
          name: config.tenant.name
        }
      }
    end

    # Normalized record completo
    expose :normalized_record do |obj|
      next nil unless obj.normalized_record

      record = obj.normalized_record

      case obj.normalized_record_type
      when "VehicleRefueling"
        {
          type: "VehicleRefueling",
          id: record.id,
          vehicle: {
            id: record.vehicle_id,
            name: record.vehicle.name,
            license_plate: record.vehicle.license_plate
          },
          refueling_date: record.refueling_date,
          volume_liters: record.volume_liters,
          cost: record.cost,
          odometer_km: record.odometer_km,
          fuel_type: record.fuel_type,
          location: record.location_lat ? {
            lat: record.location_lat,
            lng: record.location_lng
          } : nil,
          url: "/api/v1/refuelings/#{record.id}"
        }

      when "VehicleElectricCharge"
        {
          type: "VehicleElectricCharge",
          id: record.id,
          vehicle: {
            id: record.vehicle_id,
            name: record.vehicle.name,
            license_plate: record.vehicle.license_plate
          },
          charge_start_time: record.charge_start_time,
          charge_end_time: record.charge_end_time,
          energy_kwh: record.energy_consumed_kwh,
          ## cost: record.cost,
          url: "/api/v1/electric_charges/#{record.id}"
        }

      else
        {
          type: obj.normalized_record_type,
          id: obj.normalized_record_id
        }
      end
    end

    # Timeline de eventos
    expose :timeline do |obj|
      events = []

      # Creación
      events << {
        timestamp: obj.created_at,
        event: "created",
        status: "pending",
        description: "Registro raw creado"
      }

      # Normalización (éxito o error)
      if obj.normalized_at
        events << {
          timestamp: obj.normalized_at,
          event: obj.processing_status == "normalized" ? "normalization_success" : "normalization_failed",
          status: obj.processing_status,
          description: obj.processing_status == "normalized" ?
            "Normalización exitosa" :
            "Normalización fallida: #{obj.normalization_error}",
          error: obj.normalization_error
        }
      end

      # Reintentos
      if obj.retry_count && obj.retry_count > 0
        (1..obj.retry_count).each do |attempt|
          events << {
            timestamp: obj.last_retry_at, # Simplificado, idealmente guardar cada timestamp
            event: "retry_attempted",
            status: obj.processing_status,
            description: "Reintento #{attempt} - #{obj.processing_status == 'failed' ? 'Fallido' : 'Exitoso'}",
            error: obj.processing_status == "failed" ? obj.normalization_error : nil
          }
        end
      end

      # Ordenar por timestamp
      events.sort_by { |e| e[:timestamp] }
    end

    # Registros similares (mismo error/vehículo)
    expose :similar_records do |obj, opts|
      next nil unless opts[:include_similar]
      next nil unless obj.processing_status == "failed"

      # Buscar registros con el mismo error
      similar = IntegrationRawData
        .where(tenant_integration_configuration_id: obj.tenant_integration_configuration_id)
        .where(processing_status: "failed")
        .where.not(id: obj.id)
        .where("normalization_error LIKE ?", "%#{extract_key_error_part(obj.normalization_error)}%")
        .limit(5)

      {
        count: similar.count,
        records: similar.map do |rec|
          {
            id: rec.id,
            external_id: rec.external_id,
            status: rec.processing_status,
            error: rec.normalization_error,
            created_at: rec.created_at
          }
        end,
        suggestion: build_similarity_suggestion(obj, similar)
      }
    end

    # Acciones disponibles
    expose :available_actions do |obj, opts|
      Entities::IntegrationRawDataEntity.build_available_actions(obj, opts)
    end

    private

    def self.detect_error_type(obj)
      return nil unless obj.normalization_error.present?

      error_msg = obj.normalization_error.downcase

      case error_msg
      when /vehicle mapping not found|vehicle not found/
        "vehicle_not_found"
      when /authentication|credentials/
        "authentication_error"
      when /invalid.*format|missing.*field/
        "data_quality_issue"
      when /duplicate/
        "duplicate_detection"
      else
        "normalization_error"
      end
    end

    def self.calculate_duration(obj)
      return nil unless obj.normalized_at && obj.created_at
      ((obj.normalized_at - obj.created_at) * 1000).round
    end

    def self.extract_key_error_part(error_message)
      # Extraer la parte clave del error para buscar similares
      return "" unless error_message

      # Si contiene "vehicle mapping", extraer el external_id
      if error_message.include?("mapping not found")
        match = error_message.match(/external_id[:\s]+([a-zA-Z0-9_-]+)/)
        return "external_id: #{match[1]}" if match
      end

      # Si es otro tipo de error, tomar las primeras palabras clave
      error_message.split(":").first&.strip || error_message[0..50]
    end

    def self.build_similarity_suggestion(obj, similar_records)
      return nil if similar_records.empty?

      error_type = detect_error_type(obj)

      case error_type
      when "vehicle_not_found"
        external_id = obj.normalization_error.match(/external_id[:\s]+([a-zA-Z0-9_-]+)/)&.send(:[], 1)
        "Hay #{similar_records.count} registros más con el mismo vehículo no encontrado (#{external_id}). " \
        "¿Crear mapeo para resolver todos?"

      when "data_quality_issue"
        "Hay #{similar_records.count} registros más con problemas de calidad similares. " \
        "Considere verificar el normalizer o la configuración del proveedor."

      else
        "Hay #{similar_records.count} registros más con errores similares."
      end
    end
  end
end
