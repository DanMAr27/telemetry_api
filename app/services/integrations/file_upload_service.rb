# app/services/integrations/file_upload_service.rb
module Integrations
  class FileUploadService
    attr_reader :config, :file, :description, :result

    def initialize(config:, file:, description: nil)
      @config = config
      @file = file
      @description = description
      @result = {}
    end

    def call
      validate_provider!
      validate_file!

      sync_execution = create_sync_execution

      begin
        process_file(sync_execution)
        build_success_result(sync_execution)
      rescue => e
        handle_error(sync_execution, e)
        raise
      end
    end

    private

    def validate_provider!
      provider = @config.integration_provider
      unless provider.file_upload?
        raise ValidationError.new(
          "Provider '#{provider.name}' does not support file upload. Connection type: #{provider.connection_type}"
        )
      end
    end

    def validate_file!
      validate_file_type!
      validate_file_extension!
      validate_file_size!
    end

    def validate_file_type!
      allowed_types = [
        "application/vnd.ms-excel",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      ]

      file_type = @file.respond_to?(:type) ? @file.type : @file[:type]

      unless allowed_types.include?(file_type)
        raise ValidationError.new(
          "Invalid file type: #{file_type}. Only Excel files (.xlsx, .xls) are allowed."
        )
      end
    end

    def validate_file_extension!
      filename = @file.respond_to?(:filename) ? @file.filename : @file[:filename]
      ext = File.extname(filename).downcase

      unless [ ".xls", ".xlsx" ].include?(ext)
        raise ValidationError.new(
          "Invalid file extension: #{ext}. Only .xlsx and .xls files are allowed."
        )
      end
    end

    def validate_file_size!
      max_size = 10.megabytes
      file_size = @file.respond_to?(:size) ? @file.size : @file[:tempfile].size

      if file_size > max_size
        raise ValidationError.new(
          "File size (#{(file_size / 1.megabyte).round(2)} MB) exceeds maximum allowed (10 MB)."
        )
      end
    end

    def resolve_provider_module
      provider_slug = @config.integration_provider.slug
      module_name = "Integrations::#{provider_slug.camelize}"

      begin
        module_name.constantize
      rescue NameError
        raise ValidationError.new("Provider module not found: #{module_name}. Ensure provider slug matches namespace.")
      end
    end

    def create_sync_execution
      filename = @file.respond_to?(:filename) ? @file.filename : @file[:filename]
      file_size = @file.respond_to?(:size) ? @file.size : @file[:tempfile].size

      IntegrationSyncExecution.create!(
        tenant_integration_configuration: @config,
        feature_key: "financial_import",
        trigger_type: "manual",
        status: "running",
        started_at: Time.current,
        metadata: {
          file_name: filename,
          file_size: file_size,
          description: @description
        }
      )
    end

    def process_file(sync_execution)
      # Resolver módulo del proveedor dinámicamente
      provider_module = resolve_provider_module
      import_service_class = "#{provider_module}::ImportService".constantize
      normalization_service_class = "#{provider_module}::NormalizationService".constantize

      # FASE 1: Import - Crear raw data
      import_result = import_service_class.new(
        sync_execution: sync_execution,
        file: @file
      ).call

      # FASE 2: Normalization - Normalizar registros nuevos y actualizados
      normalization_errors = []
      transactions_created = 0

      # Normalizar si hay registros nuevos o actualizados
      if (import_result[:raw_data_created] + import_result[:raw_data_updated]) > 0
        # Buscar raw_data pending de esta ejecución
        raw_data_records = sync_execution.integration_raw_data.where(processing_status: "pending")

        raw_data_records.each do |raw_data|
          begin
            normalization_service_class.new(raw_data).call
            transactions_created += 1
          rescue => e
            normalization_errors << {
              external_id: raw_data.external_id,
              error: e.message
            }
          end
        end
      end

      # FASE 3: Reconciliation - Conciliar automáticamente
      reconciliation_result = {}
      if transactions_created > 0
        begin
          reconciliation_service = Financial::ReconciliationService.new(@config)
          reconciliation_result = reconciliation_service.call
        rescue => e
          Rails.logger.error("Reconciliation failed: #{e.message}")
          reconciliation_result = {
            processed: 0,
            matched: 0,
            unmatched: 0,
            unidentified: 0,
            ignored: 0,
            errors: 1,
            error_message: e.message
          }
        end
      end

      # Actualizar sync execution con resultados
      sync_execution.update!(
        status: "completed",
        finished_at: Time.current,
        duration_seconds: (Time.current - sync_execution.started_at).to_i,
        records_fetched: import_result[:total_rows],
        records_processed: transactions_created,
        records_failed: import_result[:errors].count + normalization_errors.count,
        records_skipped: import_result[:duplicates],
        duplicate_records: import_result[:duplicates],
        metadata: sync_execution.metadata.merge(
          reconciliation: reconciliation_result
        )
      )

      @result = {
        sync_execution: sync_execution,
        import_result: {
          total_rows: import_result[:total_rows],
          raw_data_created: import_result[:raw_data_created],
          raw_data_updated: import_result[:raw_data_updated],
          duplicates: import_result[:duplicates],
          transactions_created: transactions_created,
          errors: import_result[:errors] + normalization_errors
        },
        reconciliation_result: reconciliation_result
      }
    end

    def handle_error(sync_execution, error)
      sync_execution.update!(
        status: "failed",
        finished_at: Time.current,
        duration_seconds: (Time.current - sync_execution.started_at).to_i,
        records_processed: 0,
        error_message: error.message
      )
    end

    def build_success_result(sync_execution)
      response = {
        sync_execution_id: sync_execution.id,
        status: "completed",
        file_name: sync_execution.metadata["file_name"],
        file_size: sync_execution.metadata["file_size"],
        records_processed: @result[:import_result][:transactions_created],
        records_failed: @result[:import_result][:errors].count,
        duration_seconds: sync_execution.duration_seconds,
        errors: @result[:import_result][:errors],
        summary: "#{@result[:import_result][:raw_data_created]} nuevos, #{@result[:import_result][:raw_data_updated]} actualizados, #{@result[:import_result][:duplicates]} duplicados. #{@result[:import_result][:transactions_created]} transacciones normalizadas."
      }

      # Agregar estadísticas de reconciliación si están disponibles (procesados O errores)
      if @result[:reconciliation_result]&.is_a?(Hash) &&
         (@result[:reconciliation_result][:processed].to_i > 0 || @result[:reconciliation_result][:errors].to_i > 0)
        response[:reconciliation] = @result[:reconciliation_result]
      end

      response
    end

    # Custom error class
    class ValidationError < StandardError; end
  end
end
