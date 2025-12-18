# app/services/integrations/normalizers/normalize_data_service.rb
module Integrations
  module Normalizers
    class NormalizeDataService
      def initialize(execution, config)
        @execution = execution
        @config = config
        @feature_key = execution.feature_key
      end

      def call
        # PASO 1: Obtener registros RAW pendientes de normalizar
        pending_records = @execution.integration_raw_data.pending

        if pending_records.empty?
          return ServiceResult.success(
            data: { processed: 0, failed: 0 },
            message: "No hay registros pendientes de normalizar"
          )
        end

        Rails.logger.info("→ Normalizando #{pending_records.count} registros...")

        # PASO 2: Obtener el normalizador apropiado
        normalizer = get_normalizer

        # PASO 3: Procesar cada registro
        stats = process_records(pending_records, normalizer)

        # PASO 4: Retornar resultado
        ServiceResult.success(
          data: stats,
          message: "#{stats[:processed]} registros normalizados"
        )

      rescue StandardError => e
        Rails.logger.error("Error en NormalizeDataService: #{e.message}")
        ServiceResult.failure(errors: [ e.message ])
      end

      private

      # ========================================================================
      # OBTENER NORMALIZADOR
      # ========================================================================

      def get_normalizer
        Factories::NormalizerFactory.build(
          @config.integration_provider.slug,
          @feature_key
        )
      end

      # ========================================================================
      # PROCESAR REGISTROS
      # ========================================================================

      def process_records(pending_records, normalizer)
        processed = 0
        failed = 0

        pending_records.each do |raw_data|
          begin
            # Normalizar el registro
            result = normalizer.normalize(raw_data, @config)

            if result.success?
              # Éxito: marcar como normalizado y asociar al registro final
              raw_data.mark_as_normalized!(result.data)
              processed += 1
              Rails.logger.debug("  ✓ Normalizado: #{raw_data.external_id}")
            else
              # Fallo: marcar como fallido con el error
              error_message = result.errors.join(", ")
              raw_data.mark_as_failed!(error_message)
              failed += 1
              Rails.logger.warn("  ✗ Falló: #{raw_data.external_id} - #{error_message}")
            end

          rescue StandardError => e
            # Error inesperado: marcar como fallido
            raw_data.mark_as_failed!("Error inesperado: #{e.message}")
            failed += 1
            Rails.logger.error("  ✗ Error: #{raw_data.external_id} - #{e.message}")
          end
        end

        Rails.logger.info("✓ Normalización completada:")
        Rails.logger.info("  - Procesados: #{processed}")
        Rails.logger.info("  - Fallidos: #{failed}")

        { processed: processed, failed: failed }
      end
    end
  end
end
