# app/services/integrations/sync/sync_execution_service.rb
module Integrations
  module Sync
    class SyncExecutionService
      # Este servicio coordina el proceso completo:
      # 1. Validar que se puede sincronizar
      # 2. Crear registro de ejecución
      # 3. Obtener datos RAW del proveedor (vía connector)
      # 4. Guardar datos RAW
      # 5. Normalizar datos RAW
      # 6. Actualizar estadísticas

      attr_reader :config, :feature_key, :execution, :connector

      def initialize(config, feature_key, manual: true)
        @config = config
        @feature_key = feature_key
        @trigger_type = manual ? "manual" : "scheduled"
        @execution = nil
        @connector = nil
      end


      def call
        # PASO 1: Validaciones previas
        return validation_error unless valid_configuration?

        # PASO 2: Crear registro de ejecución
        create_execution_record

        # PASO 3: Ejecutar sincronización (con manejo de errores)
        begin
          execute_sync_process
          complete_execution
          update_configuration_status

          # Retornar resultado exitoso
          ServiceResult.success(
            data: build_success_response,
            message: "Sincronización completada exitosamente"
          )

        rescue StandardError => e
          # Si algo falla, marcar como fallida y retornar error
          handle_execution_error(e)

          ServiceResult.failure(
            errors: [ e.message ],
            data: { execution_id: @execution&.id }
          )
        end
      end

      private

      # ====================================================================
      # PASO 1: VALIDACIONES
      # ====================================================================

      def valid_configuration?
        # Verificar que la configuración esté activa
        return false unless @config.is_active

        # Verificar que la feature esté habilitada
        return false unless @config.enabled_features.include?(@feature_key)

        # Verificar que tenga credenciales
        return false unless @config.credentials.present?

        # Verificar que el conector esté disponible
        return false unless Factories::ConnectorFactory.provider_available?(@config.integration_provider.slug)

        true
      end

      def validation_error
        errors = []

        unless @config.is_active
          errors << "La configuración no está activa"
        end

        unless @config.enabled_features.include?(@feature_key)
          errors << "La feature '#{@feature_key}' no está habilitada"
        end

        unless @config.credentials.present?
          errors << "No hay credenciales configuradas"
        end

        unless Factories::ConnectorFactory.provider_available?(@config.integration_provider.slug)
          errors << "El proveedor no tiene conector implementado"
        end

        ServiceResult.failure(errors: errors)
      end

      # ====================================================================
      # PASO 2: CREAR REGISTRO DE EJECUCIÓN
      # ====================================================================

      def create_execution_record
        @execution = @config.integration_sync_executions.create!(
          feature_key: @feature_key,
          trigger_type: @trigger_type,
          status: "running",
          started_at: Time.current,
          metadata: {
            date_range: calculate_date_range,
            provider_slug: @config.integration_provider.slug,
            provider_name: @config.integration_provider.name
          }
        )

        Rails.logger.info("=" * 70)
        Rails.logger.info("🚀 Iniciando sincronización ##{@execution.id}")
        Rails.logger.info("   Proveedor: #{@config.integration_provider.name}")
        Rails.logger.info("   Feature: #{@feature_key}")
        Rails.logger.info("   Trigger: #{@trigger_type}")
        Rails.logger.info("=" * 70)
      end

      # ====================================================================
      # PASO 3: PROCESO DE SINCRONIZACIÓN
      # ====================================================================

      def execute_sync_process
        # PASO 3.1: Obtener conector
        # El connector ya maneja su propia autenticación internamente
        build_connector

        # PASO 3.2: Obtener datos RAW del proveedor
        fetch_raw_data

        # PASO 3.3: Normalizar datos RAW a modelos internos
        normalize_data
      end

      # ----------------------------------------------------------------------
      # PASO 3.1: Construir Connector
      # ----------------------------------------------------------------------

      def build_connector
        Rails.logger.info("→ Construyendo connector...")

        @connector = Factories::ConnectorFactory.build(
          @config.integration_provider.slug,
          @config
        )

        Rails.logger.info("✓ Connector #{@connector.class.name} construido")
      end

      # ----------------------------------------------------------------------
      # PASO 3.2: Obtener Datos RAW
      # ----------------------------------------------------------------------

      def fetch_raw_data
        Rails.logger.info("→ Obteniendo datos RAW del proveedor...")

        # Calcular rango de fechas
        date_range = calculate_date_range

        Rails.logger.info("   Desde: #{date_range[:from]}")
        Rails.logger.info("   Hasta: #{date_range[:to]}")

        # El connector maneja autenticación automáticamente
        # Si la sesión expiró, re-autentica transparentemente
        raw_response = @connector.fetch_data(
          @feature_key,
          date_range[:from],
          date_range[:to]
        )

        # Guardar registros RAW en BD
        stats = save_raw_data(raw_response)

        Rails.logger.info("✓ Datos RAW obtenidos:")
        Rails.logger.info("   Nuevos: #{stats[:created]}")
        Rails.logger.info("   Duplicados: #{stats[:duplicates]}")

      rescue Connectors::BaseConnector::AuthenticationError => e
        # Error de autenticación
        raise "Error de autenticación con #{@config.integration_provider.name}: #{e.message}"

      rescue Connectors::BaseConnector::RateLimitError => e
        # Rate limit excedido
        raise "Límite de peticiones excedido. Intente más tarde."

      rescue Connectors::BaseConnector::ServerError => e
        # Error del servidor del proveedor
        raise "Error del servidor de #{@config.integration_provider.name}: #{e.message}"

      rescue StandardError => e
        # Otro error
        raise "Error al obtener datos: #{e.message}"
      end

      def save_raw_data(raw_response)
        created_count = 0
        duplicates_count = 0

        # raw_response es un Array de Hashes
        raw_response.each do |record|
          # Extraer ID único del proveedor
          external_id = extract_external_id(record)

          # Crear o detectar duplicado
          raw_data = IntegrationRawData.create_or_mark_duplicate(
            integration_sync_execution: @execution,
            tenant_integration_configuration: @config,
            provider_slug: @config.integration_provider.slug,
            feature_key: @feature_key,
            external_id: external_id,
            raw_data: record,
            processing_status: "pending"
          )

          if raw_data.duplicate?
            duplicates_count += 1
            Rails.logger.debug("  ⊘ Duplicado: #{external_id}")
          else
            created_count += 1
            Rails.logger.debug("  ✓ Nuevo: #{external_id}")
          end
        end

        { created: created_count, duplicates: duplicates_count }
      end

      def extract_external_id(record)
        # El ID del registro en el proveedor
        # Geotab usa campo "id"
        record["id"] || record[:id] || raise("Registro sin ID: #{record.inspect}")
      end

      # ----------------------------------------------------------------------
      # PASO 3.3: Normalizar Datos
      # ----------------------------------------------------------------------

      def normalize_data
        Rails.logger.info("→ Normalizando datos...")

        # Delegar al servicio de normalización
        result = Normalizers::NormalizeDataService.new(
          @execution,
          @config
        ).call

        if result.success?
          stats = result.data
          Rails.logger.info("✓ Normalización completada:")
          Rails.logger.info("   Procesados: #{stats[:processed]}")
          Rails.logger.info("   Fallidos: #{stats[:failed]}")
        else
          Rails.logger.warn("⚠ Normalización con errores: #{result.errors.join(', ')}")
        end
      end

      # ====================================================================
      # PASO 4: COMPLETAR EJECUCIÓN
      # ====================================================================

      def complete_execution
        # Calcular estadísticas finales
        stats = calculate_statistics

        # Actualizar registro de ejecución
        @execution.update!(
          status: "completed",
          finished_at: Time.current,
          duration_seconds: (Time.current - @execution.started_at).to_i,
          records_fetched: stats[:fetched],
          records_processed: stats[:processed],
          records_failed: stats[:failed],
          records_skipped: stats[:skipped]
        )

        Rails.logger.info("=" * 70)
        Rails.logger.info("✅ Sincronización ##{@execution.id} completada")
        Rails.logger.info("   Duración: #{@execution.duration_seconds}s")
        Rails.logger.info("   Tasa de éxito: #{@execution.success_rate}%")
        Rails.logger.info("=" * 70)
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

      # ====================================================================
      # PASO 5: ACTUALIZAR CONFIGURACIÓN
      # ====================================================================

      def update_configuration_status
        @config.update!(
          last_sync_at: Time.current,
          last_sync_status: "success",
          last_sync_error: nil
        )
      end

      # ====================================================================
      # MANEJO DE ERRORES
      # ====================================================================

      def handle_execution_error(error)
        Rails.logger.error("=" * 70)
        Rails.logger.error("❌ Error en sincronización ##{@execution&.id}")
        Rails.logger.error("   Mensaje: #{error.message}")
        Rails.logger.error("   Tipo: #{error.class.name}")
        Rails.logger.error("=" * 70)
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

      # ====================================================================
      # UTILIDADES
      # ====================================================================

      def calculate_date_range
        # Estrategia de sincronización:
        # - Primera sync: últimos 30 días
        # - Incremental: desde última exitosa (con overlap de 2h)

        if first_sync?
          {
            from: 30.days.ago.beginning_of_day,
            to: Time.current,
            strategy: :initial
          }
        else
          {
            from: @config.last_sync_at - 2.hours, # Overlap para evitar gaps
            to: Time.current,
            strategy: :incremental
          }
        end
      end

      def first_sync?
        @config.last_sync_at.nil? || @config.last_sync_status != "success"
      end

      def build_success_response
        {
          execution_id: @execution.id,
          feature_key: @feature_key,
          provider_name: @config.integration_provider.name,
          records_fetched: @execution.records_fetched,
          records_processed: @execution.records_processed,
          records_failed: @execution.records_failed,
          records_skipped: @execution.records_skipped,
          duration_seconds: @execution.duration_seconds,
          success_rate: @execution.success_rate,
          started_at: @execution.started_at,
          finished_at: @execution.finished_at,
          warnings: build_warnings
        }
      end

      def build_warnings
        warnings = []

        if @execution.records_failed > 0
          warnings << "#{@execution.records_failed} registros fallaron al normalizar"
        end

        if @execution.records_skipped > 0
          warnings << "#{@execution.records_skipped} registros duplicados omitidos"
        end

        warnings
      end
    end
  end
end
