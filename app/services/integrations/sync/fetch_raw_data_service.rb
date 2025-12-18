# app/services/integrations/sync/fetch_raw_data_service.rb
module Integrations
  module Sync
    class FetchRawDataService
      def initialize(execution, config, session_id, feature_key, date_range)
        @execution = execution
        @config = config
        @session_id = session_id
        @feature_key = feature_key
        @date_range = date_range
        @provider = config.integration_provider
      end

      def call
        # PASO 1: Obtener el conector apropiado
        connector = get_connector

        # PASO 2: Llamar al método fetch del conector según la feature
        raw_response = fetch_from_provider(connector)

        # PASO 3: Guardar cada registro en integration_raw_data
        result = save_raw_data(raw_response)

        ServiceResult.success(
          data: result,
          message: "#{result[:records_created]} registros obtenidos"
        )

      rescue StandardError => e
        Rails.logger.error("Error en FetchRawDataService: #{e.message}")
        ServiceResult.failure(errors: [ e.message ])
      end

      private

      # ========================================================================
      # OBTENER CONECTOR
      # ========================================================================

      def get_connector
        Factories::ConnectorFactory.build(@provider.slug)
      end

      # ========================================================================
      # LLAMAR API DEL PROVEEDOR
      # ========================================================================

      def fetch_from_provider(connector)
        # Según la feature, llamar al método correspondiente del conector
        case @feature_key
        when "fuel"
          connector.fetch_refuelings(@session_id, @date_range[:from], @date_range[:to])
        when "battery"
          connector.fetch_electric_charges(@session_id, @date_range[:from], @date_range[:to])
        when "trips"
          connector.fetch_trips(@session_id, @date_range[:from], @date_range[:to])
        else
          raise ArgumentError, "Feature no soportada: #{@feature_key}"
        end
      end

      # ========================================================================
      # GUARDAR DATOS RAW EN BD
      # ========================================================================

      def save_raw_data(raw_response)
        records_created = 0
        duplicates_count = 0
        errors = []

        # raw_response es un Array de Hashes
        # Ejemplo: [{ id: 'abc123', volume: 57.3, ... }, { id: 'def456', ... }]

        raw_response.each do |record|
          begin
            # Extraer el ID único del registro del proveedor
            external_id = extract_external_id(record)

            # Intentar crear el registro RAW
            raw_data = create_raw_data_record(external_id, record)

            if raw_data.duplicate?
              duplicates_count += 1
              Rails.logger.debug("  ⊘ Duplicado: #{external_id}")
            else
              records_created += 1
              Rails.logger.debug("  ✓ Guardado: #{external_id}")
            end

          rescue StandardError => e
            # Si falla al guardar un registro individual, continuamos con los demás
            errors << "Error al guardar registro: #{e.message}"
            Rails.logger.error("Error al guardar registro: #{e.message}")
          end
        end

        # Logear resumen
        Rails.logger.info("→ Datos RAW guardados:")
        Rails.logger.info("  - Nuevos: #{records_created}")
        Rails.logger.info("  - Duplicados: #{duplicates_count}")
        Rails.logger.info("  - Errores: #{errors.count}")

        {
          records_created: records_created,
          duplicates_count: duplicates_count,
          errors_count: errors.count,
          errors: errors
        }
      end

      # ========================================================================
      # CREAR REGISTRO RAW DATA
      # ========================================================================

      def create_raw_data_record(external_id, record)
        # Usar el método especial que detecta duplicados automáticamente
        IntegrationRawData.create_or_mark_duplicate(
          integration_sync_execution: @execution,
          tenant_integration_configuration: @config,
          provider_slug: @provider.slug,
          feature_key: @feature_key,
          external_id: external_id,
          raw_data: record,
          processing_status: "pending"
        )
      end

      # ========================================================================
      # EXTRAER EXTERNAL_ID DEL REGISTRO
      # ========================================================================

      def extract_external_id(record)
        # El external_id es el campo 'id' en la respuesta del proveedor
        # Ejemplo Geotab: { "id": "a8LfU7K7fpkOFf7XOZw-uCg", ... }
        record["id"] || record[:id] || raise("Registro sin ID: #{record}")
      end
    end
  end
end
