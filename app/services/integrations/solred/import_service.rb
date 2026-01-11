# app/services/integrations/solred/import_service.rb
module Integrations
  module Solred
    class ImportService
      attr_reader :sync_execution, :file, :errors, :raw_data_created, :raw_data_updated, :duplicates

      def initialize(sync_execution:, file:)
        @sync_execution = sync_execution
        @file = file
        @errors = []
        @raw_data_created = 0
        @raw_data_updated = 0
        @duplicates = 0
      end

      def call
        # Abrir archivo Excel con Roo
        spreadsheet = open_spreadsheet

        # Validar estructura del archivo
        validate_structure!(spreadsheet)

        # Procesar cada fila
        process_rows(spreadsheet)

        # Retornar resultado
        {
          total_rows: spreadsheet.last_row - 1, # Excluir header
          raw_data_created: @raw_data_created,
          raw_data_updated: @raw_data_updated,
          duplicates: @duplicates,
          errors: @errors
        }
      rescue => e
        @errors << { row: 0, error: e.message }
        raise e
      end

      private

      def open_spreadsheet
        # Obtener filename y tempfile del objeto file
        filename = @file.respond_to?(:filename) ? @file.filename : @file[:filename]
        tempfile = @file.respond_to?(:tempfile) ? @file.tempfile : @file[:tempfile]

        case File.extname(filename).downcase
        when ".xlsx"
          Roo::Excelx.new(tempfile.path)
        when ".xls"
          Roo::Excel.new(tempfile.path)
        else
          raise "Unsupported file type: #{filename}"
        end
      end

      def validate_structure!(spreadsheet)
        # Columnas esperadas de Solred (estructura real del archivo)
        expected_columns = [
          "NUM_REFER",
          "FEC_OPERAC",
          "HOR_OPERAC",
          "MATRICULA",
          "NUM_TARJET",
          "NOM_ESTABL",
          "COD_PRODU",
          "DES_PRODU",
          "NUM_LITROS",
          "PU_LITRO",
          "IMPORTE",
          "DCTO_FIJO",
          "BONIF_TOTAL",
          "IMP_TOTAL",
          "COD_CONTROL"
        ]

        # Leer primera fila (headers)
        headers = spreadsheet.row(1)

        # Verificar que todas las columnas esperadas estén presentes
        missing_columns = expected_columns - headers
        if missing_columns.any?
          raise "Missing required columns: #{missing_columns.join(', ')}"
        end
      end

      def process_rows(spreadsheet)
        # Iterar desde la fila 2 (después del header)
        (2..spreadsheet.last_row).each do |row_num|
          begin
            row_data = parse_row(spreadsheet, row_num)
            result = create_raw_data(row_data)

            case result[:status]
            when :created
              @raw_data_created += 1
            when :updated
              @raw_data_updated += 1
            when :duplicate
              @duplicates += 1
            end
          rescue => e
            @errors << { row: row_num, error: e.message }
          end
        end
      end

      def create_raw_data(row_data)
        external_id = row_data[:num_refer]
        new_raw_data = row_data.transform_keys(&:to_s)

        # Buscar si ya existe (solo por external_id, ignorando estado)
        existing = IntegrationRawData.find_by(
          tenant_integration_configuration: @sync_execution.tenant_integration_configuration,
          external_id: external_id,
          feature_key: "financial_import"
        )

        if existing
          # Existe: comparar SOLO los datos, NO el estado
          if existing.raw_data != new_raw_data
            # Datos cambiaron: actualizar raw_data y resetear a pending
            existing.update!(
              raw_data: new_raw_data,
              processing_status: "pending",
              integration_sync_execution: @sync_execution,
              normalized_record_type: nil,
              normalized_record_id: nil,
              normalization_error: nil,
              normalized_at: nil
            )
            { status: :updated, record: existing }
          else
            # Duplicado idéntico: skip (sin importar el estado actual)
            { status: :duplicate, record: nil }
          end
        else
          # No existe: crear nuevo
          record = IntegrationRawData.create!(
            integration_sync_execution: @sync_execution,
            tenant_integration_configuration: @sync_execution.tenant_integration_configuration,
            provider_slug: "solred",
            feature_key: "financial_import",
            external_id: external_id,
            raw_data: new_raw_data,
            processing_status: "pending"
          )
          { status: :created, record: record }
        end
      end

      def parse_row(spreadsheet, row_num)
        row = spreadsheet.row(row_num)
        headers = spreadsheet.row(1)

        # Crear hash con índices de columnas
        col_idx = {}
        headers.each_with_index { |h, i| col_idx[h] = i }

        # Obtener valor de fecha directamente (sin parsear aquí)
        fecha_raw = row[col_idx["FEC_OPERAC"]]

        # Mapeo de columnas según estructura real de Solred
        {
          num_refer: row[col_idx["NUM_REFER"]]&.to_s,
          cod_control: row[col_idx["COD_CONTROL"]]&.to_s,
          fecha: fecha_raw&.to_s,  # Guardar como string sin parsear
          hora: row[col_idx["HOR_OPERAC"]]&.to_s,
          matricula: row[col_idx["MATRICULA"]]&.to_s&.strip,
          num_tarjeta: row[col_idx["NUM_TARJET"]]&.to_s,
          establecimiento: row[col_idx["NOM_ESTABL"]]&.to_s,
          cod_producto: row[col_idx["COD_PRODU"]]&.to_s,
          producto: row[col_idx["DES_PRODU"]]&.to_s,
          cantidad: row[col_idx["NUM_LITROS"]]&.to_f,
          p_unitario: row[col_idx["PU_LITRO"]]&.to_f,
          importe: row[col_idx["IMPORTE"]]&.to_f,
          dcto_fijo: row[col_idx["DCTO_FIJO"]]&.to_f || 0,
          bonif_total: row[col_idx["BONIF_TOTAL"]]&.to_f || 0,
          total: row[col_idx["IMP_TOTAL"]]&.to_f
        }
      end

      def parse_date(date_value)
        # Manejar diferentes formatos de fecha
        case date_value
        when Date, DateTime, Time
          date_value.to_date
        when String
          # Formato Solred: YYYYMMDD (ej: 20251101)
          if date_value.match?(/^\d{8}$/)
            Date.strptime(date_value, "%Y%m%d")
          else
            Date.parse(date_value)
          end
        when Numeric
          # Excel almacena fechas como números
          Date.new(1899, 12, 30) + date_value.to_i
        else
          raise "Invalid date format: #{date_value}"
        end
      end
    end
  end
end
