# app/services/integrations/sync/sync_execution_service.rb
module Integrations
  module Sync
    class SyncExecutionService
      def initialize(config, feature_key, manual: true, date_range: nil)
        @config = config
        @feature_key = feature_key
        @trigger_type = manual ? "manual" : "scheduled"
        @custom_date_range = date_range
        @execution = nil
        @session_data = nil  # Cambiado de @session_id a @session_data
      end

      def call
        # PASO 1: Validaciones previas
        return validation_error unless valid_configuration?

        # PASO 2: Crear registro de ejecución
        create_execution_record

        # PASO 3: Ejecutar sincronización
        begin
          execute_sync_process

          # PASO 4: Marcar como completada
          complete_execution

          # PASO 5: Actualizar configuración
          update_configuration_status

          # Retornar resultado exitoso
          ServiceResult.success(
            data: build_success_response,
            message: "Sincronización completada exitosamente"
          )

        rescue StandardError => e
          handle_execution_error(e)
          ServiceResult.failure(
            errors: [ e.message ],
            data: { execution_id: @execution&.id }
          )
        end
      end

      private

      # ========================================================================
      # VALIDACIONES
      # ========================================================================

      def valid_configuration?
        return false unless @config.is_active
        return false unless @config.enabled_features.include?(@feature_key)
        return false unless @config.credentials.present?
        true
      end

      def validation_error
        errors = []
        errors << "Configuración no activa" unless @config.is_active
        errors << "Feature '#{@feature_key}' no habilitada" unless @config.enabled_features.include?(@feature_key)
        errors << "Credenciales no configuradas" unless @config.credentials.present?

        ServiceResult.failure(errors: errors)
      end

      # ========================================================================
      # CREAR REGISTRO DE EJECUCIÓN
      # ========================================================================

      def create_execution_record
        @execution = @config.integration_sync_executions.create!(
          feature_key: @feature_key,
          started_at: Time.current,
          metadata: {
            date_range: calculate_date_range,
            provider_slug: @config.integration_provider.slug
          }
        )

        Rails.logger.info("✓ Ejecución ##{@execution.id} creada (#{@feature_key})")
      end

      # ========================================================================
      # PROCESO DE SINCRONIZACIÓN
      # ========================================================================

      def execute_sync_process
        authenticate
        fetch_raw_data
        normalize_data
      end

      # ------------------------------------------------------------------------
      # PASO 1: AUTENTICACIÓN
      # ------------------------------------------------------------------------

      def authenticate
        Rails.logger.info("→ Autenticando con #{@config.integration_provider.name}...")

        auth_result = Integrations::Authentication::AuthenticateService.new(@config).call

        if auth_result.failure?
          raise "Error de autenticación: #{auth_result.errors.join(', ')}"
        end

        # Ahora guardamos el objeto completo con session_id, database y username
        @session_data = auth_result.data

        Rails.logger.info("✓ Autenticación exitosa")
        Rails.logger.info("  - Session: #{@session_data[:session_id][0..10]}...")
        Rails.logger.info("  - Database: #{@session_data[:database]}")
        Rails.logger.info("  - Username: #{@session_data[:username]}")
      end

      # ------------------------------------------------------------------------
      # PASO 2: OBTENER DATOS RAW
      # ------------------------------------------------------------------------

      def fetch_raw_data
        Rails.logger.info("→ Obteniendo datos RAW de #{@feature_key}...")

        date_range = calculate_date_range

        # Pasamos session_data completo (no solo session_id)
        fetch_result = Integrations::Sync::FetchRawDataService.new(
          @execution,
          @config,
          @session_data,  # ✅ Ahora pasa el Hash completo
          @feature_key,
          date_range
        ).call

        if fetch_result.failure?
          raise "Error al obtener datos: #{fetch_result.errors.join(', ')}"
        end

        records_count = fetch_result.data[:records_created]
        duplicates_count = fetch_result.data[:duplicates_count]

        Rails.logger.info("✓ #{records_count} registros RAW obtenidos (#{duplicates_count} duplicados omitidos)")
      end

      # ------------------------------------------------------------------------
      # PASO 3: NORMALIZAR DATOS
      # ------------------------------------------------------------------------

      def normalize_data
        Rails.logger.info("→ Normalizando datos...")

        normalize_result = Integrations::Normalizers::NormalizeDataService.new(
          @execution,
          @config
        ).call

        if normalize_result.failure?
          Rails.logger.warn("⚠ Normalización con errores: #{normalize_result.errors.join(', ')}")
        end

        stats = normalize_result.data
        Rails.logger.info("✓ Normalización completada:")
        Rails.logger.info("  - Procesados: #{stats[:processed]}")
        Rails.logger.info("  - Fallidos: #{stats[:failed]}")
      end

      # ========================================================================
      # COMPLETAR EJECUCIÓN
      # ========================================================================

      def complete_execution
        stats = calculate_statistics

        @execution.update!(
          status: "completed",
          finished_at: Time.current,
          duration_seconds: (Time.current - @execution.started_at).to_i,
          records_fetched: stats[:fetched],
          records_processed: stats[:processed],
          records_failed: stats[:failed],
          records_skipped: stats[:skipped]
        )

        Rails.logger.info("✅ Ejecución ##{@execution.id} completada (#{@execution.duration_seconds}s)")
      end

      def calculate_statistics
        raw_data = @execution.integration_raw_data

        {
          fetched: raw_data.count,
          processed: raw_data.normalized.count,
          failed: raw_data.failed.count,
          skipped: raw_data.duplicate.count
        }
      end

      # ========================================================================
      # ACTUALIZAR CONFIGURACIÓN
      # ========================================================================

      def update_configuration_status
        @config.update!(
          last_sync_at: Time.current,
          last_sync_status: "success",
          last_sync_error: nil
        )
      end

      # ========================================================================
      # MANEJO DE ERRORES
      # ========================================================================

      def handle_execution_error(error)
        Rails.logger.error("❌ Error en ejecución ##{@execution&.id}: #{error.message}")
        Rails.logger.error(error.backtrace.join("\n"))

        if @execution
          @execution.update!(
            status: "failed",
            finished_at: Time.current,
            duration_seconds: (Time.current - @execution.started_at).to_i,
            error_message: error.message
          )
        end

        @config.update!(
          last_sync_at: Time.current,
          last_sync_status: "error",
          last_sync_error: error.message
        )
      end

      # ========================================================================
      # UTILIDADES
      # ========================================================================

      def calculate_date_range
        return @custom_date_range if @custom_date_range.present?

        from_date = if @config.last_sync_at && @config.last_sync_at > 30.days.ago
                     @config.last_sync_at
        else
                     30.days.ago
        end

        to_date = Time.current

        Rails.logger.info("📅 Rango de fechas: #{from_date.strftime('%Y-%m-%d')} → #{to_date.strftime('%Y-%m-%d')}")

        { from: from_date, to: to_date }
      end

      def build_success_response
        {
          execution_id: @execution.id,
          feature_key: @feature_key,
          records_fetched: @execution.records_fetched,
          records_processed: @execution.records_processed,
          records_failed: @execution.records_failed,
          records_skipped: @execution.records_skipped,
          duration_seconds: @execution.duration_seconds,
          started_at: @execution.started_at,
          finished_at: @execution.finished_at,
          success_rate: @execution.success_rate,
          warnings: build_warnings
        }
      end

      def build_warnings
        warnings = []
        warnings << "#{@execution.records_failed} registros fallaron al normalizar" if @execution.records_failed > 0
        warnings << "#{@execution.records_skipped} registros duplicados omitidos" if @execution.records_skipped > 0
        warnings
      end
    end
  end
end
