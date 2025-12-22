# app/services/integrations/normalizers/normalize_data_service.rb (CORREGIDO)
module Integrations
  module Normalizers
    class NormalizeDataService
      def initialize(execution, config)
        @execution = execution
        @config = config
        @feature_key = execution.feature_key
      end

      def call
        # PASO 1: Obtener registros RAW pendientes
        pending_records = @execution.integration_raw_data.pending

        if pending_records.empty?
          return ServiceResult.success(
            data: { processed: 0, failed: 0, skipped: 0 },
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
          message: "#{stats[:processed]} registros normalizados, #{stats[:failed]} fallidos"
        )

      rescue StandardError => e
        Rails.logger.error("Error en NormalizeDataService: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))

        # Retornar stats parciales incluso si hubo error
        ServiceResult.success(
          data: {
            processed: 0,
            failed: pending_records.count,
            skipped: 0,
            error: e.message
          },
          message: "Error general en normalización: #{e.message}"
        )
      end

      private

      def get_normalizer
        Factories::NormalizerFactory.build(
          @config.integration_provider.slug,
          @feature_key
        )
      end

      def process_records(pending_records, normalizer)
        processed = 0
        failed = 0
        skipped = 0

        pending_records.each do |raw_data|
          begin
            # Normalizar el registro
            result = normalizer.normalize(raw_data, @config)

            if result.success?
              raw_data.mark_as_normalized!(result.data)
              processed += 1
              Rails.logger.debug("  ✓ Normalizado: #{raw_data.external_id}")
            else
              # Fallo en normalización
              error_message = result.errors.join(", ")
              raw_data.mark_as_failed!(error_message)
              failed += 1
              Rails.logger.warn("  ✗ Falló: #{raw_data.external_id} - #{error_message}")
            end

          rescue StandardError => e
            # Error inesperado: marcar como fallido y continuar
            Rails.logger.error("  ✗ Error inesperado: #{raw_data.external_id}")
            Rails.logger.error("     #{e.class.name}: #{e.message}")

            begin
              raw_data.mark_as_failed!("Error inesperado: #{e.message}", error_type: "unexpected_error")
              failed += 1
            rescue => marking_error
              # Si ni siquiera podemos marcar como fallido, loguear y continuar
              Rails.logger.error("  ✗✗ No se pudo marcar error: #{marking_error.message}")
              skipped += 1
            end
          end
        end

        Rails.logger.info("✓ Normalización completada:")
        Rails.logger.info("  - Procesados: #{processed}")
        Rails.logger.info("  - Fallidos: #{failed}")
        Rails.logger.info("  - Omitidos: #{skipped}")

        {
          processed: processed,
          failed: failed,
          skipped: skipped
        }
      end
    end
  end
end
