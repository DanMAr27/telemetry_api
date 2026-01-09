# app/services/integrations/sync/sync_execution_service.rb
module Integrations
  module Sync
    class SyncExecutionService
      attr_reader :config, :feature_key, :execution, :connector

      def initialize(config, feature_key, manual: true)
        @config = config
        @feature_key = feature_key
        @trigger_type = manual ? "manual" : "scheduled"
        @execution = nil
        @connector = nil
        @stats = {
          fetched: 0,
          created: 0,
          duplicates: 0,
          processed: 0,
          failed: 0,
          skipped: 0
        }
      end

      def call
        return validation_error unless valid_configuration?

        create_execution_record

        begin
          execute_sync_process
          complete_execution
          update_configuration_status

          ServiceResult.success(
            data: build_success_response,
            message: build_completion_message
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

      def valid_configuration?
        return false unless @config.is_active
        return false unless @config.enabled_features.include?(@feature_key)
        return false unless @config.credentials.present?
        return false unless Factories::ConnectorFactory.provider_available?(@config.integration_provider.slug)
        true
      end

      def validation_error
        errors = []
        errors << "La configuración no está activa" unless @config.is_active
        errors << "La feature '#{@feature_key}' no está habilitada" unless @config.enabled_features.include?(@feature_key)
        errors << "No hay credenciales configuradas" unless @config.credentials.present?
        errors << "El proveedor no tiene conector implementado" unless Factories::ConnectorFactory.provider_available?(@config.integration_provider.slug)

        ServiceResult.failure(errors: errors)
      end

      def create_execution_record
        date_range = calculate_date_range

        @execution = @config.integration_sync_executions.create!(
          feature_key: @feature_key,
          trigger_type: @trigger_type,
          status: "running",
          started_at: Time.current,
          metadata: {
            date_range: date_range,
            provider_slug: @config.integration_provider.slug,
            provider_name: @config.integration_provider.name
          }
        )

        Rails.logger.info("=" * 70)
        Rails.logger.info("🚀 Iniciando sincronización ##{@execution.id}")
        Rails.logger.info("   Proveedor: #{@config.integration_provider.name}")
        Rails.logger.info("   Feature: #{@feature_key}")
        Rails.logger.info("   Trigger: #{@trigger_type}")
        Rails.logger.info("   Desde: #{date_range[:from]}")
        Rails.logger.info("   Hasta: #{date_range[:to]}")
        Rails.logger.info("   Estrategia: #{date_range[:strategy]}")
        Rails.logger.info("=" * 70)
      end

      def execute_sync_process
        build_connector
        fetch_raw_data
        normalize_data
      end

      def build_connector
        Rails.logger.info("→ Construyendo connector...")
        @connector = Factories::ConnectorFactory.build(
          @config.integration_provider.slug,
          @config
        )
        Rails.logger.info("✓ Connector #{@connector.class.name} construido")
      end

      def fetch_raw_data
        Rails.logger.info("→ Obteniendo datos RAW del proveedor...")

        # AQUÍ ESTÁ LA CLAVE: usar el mismo date_range que guardamos en metadata
        date_range = @execution.metadata["date_range"].symbolize_keys

        Rails.logger.info("   Desde: #{date_range[:from]} (#{date_range[:from].class})")
        Rails.logger.info("   Hasta: #{date_range[:to]} (#{date_range[:to].class})")
        Rails.logger.info("   Estrategia: #{date_range[:strategy]}")

        # LLAMADA AL CONNECTOR CON FECHAS
        raw_response = @connector.fetch_data(
          @feature_key,
          date_range[:from],
          date_range[:to]
        )

        save_raw_data(raw_response)

        Rails.logger.info("✓ Datos RAW procesados:")
        Rails.logger.info("   Obtenidos: #{@stats[:fetched]}")
        Rails.logger.info("   Nuevos: #{@stats[:created]}")
        Rails.logger.info("   Duplicados: #{@stats[:duplicates]}")

      rescue Connectors::BaseConnector::AuthenticationError => e
        raise "Error de autenticación con #{@config.integration_provider.name}: #{e.message}"
      rescue Connectors::BaseConnector::RateLimitError => e
        raise "Límite de peticiones excedido. Intente más tarde."
      rescue Connectors::BaseConnector::ServerError => e
        raise "Error del servidor de #{@config.integration_provider.name}: #{e.message}"
      rescue StandardError => e
        raise "Error al obtener datos: #{e.message}"
      end

      def save_raw_data(raw_response)
        @stats[:fetched] = raw_response.size
        duplicate_ids = []

        raw_response.each do |record|
          external_id = extract_external_id(record)

          raw_data = IntegrationRawData.create_or_handle_duplicate(
            integration_sync_execution: @execution,
            tenant_integration_configuration: @config,
            provider_slug: @config.integration_provider.slug,
            feature_key: @feature_key,
            external_id: external_id,
            raw_data: record,
            processing_status: "pending"
          )

          if raw_data.nil?
            # Duplicado idéntico → no se creó registro
            @stats[:duplicates] += 1
            duplicate_ids << external_id
            Rails.logger.debug("  ⊘ Duplicado descartado: #{external_id}")
          else
            # Nuevo o actualizado
            @stats[:created] += 1
            Rails.logger.debug("  ✓ Nuevo registro: #{external_id}")
          end
        end

        # Guardar los external_ids duplicados en el metadata de la ejecución
        if duplicate_ids.any?
          @execution.update_column(
            :duplicate_external_ids,
            (@execution.duplicate_external_ids || []) + duplicate_ids
          )
        end
      end

      def extract_external_id(record)
        record["id"] || record[:id] || raise("Registro sin ID: #{record.inspect}")
      end

      def normalize_data
        Rails.logger.info("→ Normalizando datos...")

        result = Normalizers::NormalizeDataService.new(
          @execution,
          @config
        ).call

        if result.success?
          @stats.merge!(result.data)
          Rails.logger.info("✓ Normalización completada:")
          Rails.logger.info("   Procesados: #{@stats[:processed]}")
          Rails.logger.info("   Fallidos: #{@stats[:failed]}")
          Rails.logger.info("   Omitidos: #{@stats[:skipped]}")
        else
          Rails.logger.warn("⚠ Normalización con errores: #{result.errors.join(', ')}")
        end
      end

      def complete_execution
        @execution.update_columns(
          status: determine_final_status,
          finished_at: Time.current,
          duration_seconds: (Time.current - @execution.started_at).to_i,
          records_fetched: @stats[:fetched],
          records_processed: @stats[:processed],
          records_failed: @stats[:failed],
          records_skipped: @stats[:duplicates] + @stats[:skipped],
          duplicate_records: @stats[:duplicates],
          updated_at: Time.current
        )

        Rails.logger.info("=" * 70)
        Rails.logger.info("#{status_emoji} Sincronización ##{@execution.id} #{@execution.status}")
        Rails.logger.info("   Duración: #{@execution.duration_seconds}s")
        Rails.logger.info("   Obtenidos: #{@stats[:fetched]}")
        Rails.logger.info("   Nuevos: #{@stats[:created]}")
        Rails.logger.info("   Procesados: #{@stats[:processed]}")
        Rails.logger.info("   Fallidos: #{@stats[:failed]}")
        Rails.logger.info("   Duplicados: #{@stats[:duplicates]}")

        if @stats[:failed] > 0
          Rails.logger.warn("   ⚠ #{@stats[:failed]} registros con errores de normalización")
        end

        if @stats[:duplicates] > 0
          Rails.logger.info("   ℹ #{@stats[:duplicates]} registros duplicados omitidos")
        end

        Rails.logger.info("=" * 70)
      end

      def determine_final_status
        if @stats[:created] == 0
          "completed"
        elsif @stats[:failed] == @stats[:created]
          "failed"
        elsif @stats[:processed] > 0
          "completed"
        else
          "completed"
        end
      end

      def status_emoji
        case @execution.status
        when "completed"
          @stats[:failed] > 0 ? "Warning" : "OK"
        when "failed"
          "failed"
        else
          "Otros"
        end
      end

      def update_configuration_status
        if @execution.status == "completed"
          @config.update!(
            last_sync_at: Time.current,
            last_sync_status: @stats[:failed] > 0 ? "partial" : "success",
            last_sync_error: @stats[:failed] > 0 ? "#{@stats[:failed]} registros con errores" : nil
          )
        else
          @config.update!(
            last_sync_at: Time.current,
            last_sync_status: "error",
            last_sync_error: @execution.error_message
          )
        end
      end

      def handle_execution_error(error)
        Rails.logger.error("=" * 70)
        Rails.logger.error("Error en sincronización ##{@execution&.id}")
        Rails.logger.error("   Mensaje: #{error.message}")
        Rails.logger.error("   Tipo: #{error.class.name}")
        Rails.logger.error("=" * 70)
        Rails.logger.error(error.backtrace.first(10).join("\n"))

        if @execution
          @execution.update_columns(
            status: "failed",
            finished_at: Time.current,
            duration_seconds: (Time.current - @execution.started_at).to_i,
            error_message: error.message,
            records_fetched: @stats[:fetched],
            records_processed: @stats[:processed],
            records_failed: @stats[:failed],
            records_skipped: @stats[:duplicates] + @stats[:skipped],
            duplicate_records: @stats[:duplicates],
            updated_at: Time.current
          )
        end

        @config.update!(
          last_sync_at: Time.current,
          last_sync_status: "error",
          last_sync_error: error.message
        )
      end

      def calculate_date_range
        if first_sync?
          # Primera sincronización: traer últimos 30 días
          {
            from: 30.days.ago.beginning_of_day,
            to: Time.current,
            strategy: :initial
          }
        elsif manual_sync?
          # Sincronización manual: traer últimos 30 días siempre
          {
            from: 30.days.ago.beginning_of_day,
            to: Time.current,
            strategy: :manual_full
          }
        else
          # Sincronización automática/scheduled: incremental desde última sync
          {
            from: @config.last_sync_at - 2.hours,
            to: Time.current,
            strategy: :incremental
          }
        end
      end

      def first_sync?
        @config.last_sync_at.nil? || @config.last_sync_status != "success"
      end

      def manual_sync?
        @trigger_type == "manual"
      end

      def build_success_response
        {
          execution_id: @execution.id,
          feature_key: @feature_key,
          provider_name: @config.integration_provider.name,
          records_fetched: @stats[:fetched],
          records_created: @stats[:created],
          records_processed: @stats[:processed],
          records_failed: @stats[:failed],
          records_duplicated: @stats[:duplicates],
          records_skipped: @stats[:skipped],
          duration_seconds: @execution.duration_seconds,
          success_rate: calculate_success_rate,
          started_at: @execution.started_at,
          finished_at: @execution.finished_at,
          warnings: build_warnings,
          has_errors: @stats[:failed] > 0
        }
      end

      def calculate_success_rate
        return 100.0 if @stats[:created].zero?
        ((@stats[:processed].to_f / @stats[:created]) * 100).round(2)
      end

      def build_warnings
        warnings = []

        if @stats[:failed] > 0
          warnings << "#{@stats[:failed]} registros fallaron al normalizar (pueden reprocesarse)"
        end

        if @stats[:duplicates] > 0
          warnings << "#{@stats[:duplicates]} registros duplicados omitidos"
        end

        if @stats[:skipped] > 0
          warnings << "#{@stats[:skipped]} registros omitidos por validación"
        end

        warnings
      end

      def build_completion_message
        if @stats[:failed].zero? && @stats[:created] > 0
          "Sincronización completada exitosamente: #{@stats[:processed]} registros procesados"
        elsif @stats[:created].zero?
          "Sincronización completada: solo registros duplicados encontrados"
        elsif @stats[:failed] > 0
          "Sincronización completada con advertencias: #{@stats[:processed]} procesados, #{@stats[:failed]} con errores"
        else
          "Sincronización completada"
        end
      end
    end
  end
end
