# app/services/integrations/solred/normalization_service.rb
module Integrations
  module Solred
    class NormalizationService
      attr_reader :raw_data_record, :errors

      def initialize(raw_data_record)
        @raw_data_record = raw_data_record
        @data = raw_data_record.raw_data.with_indifferent_access
        @errors = []
      end

      def call
        validate_data!

        transaction = create_financial_transaction

        # Marcar como procesado usando el método del modelo
        @raw_data_record.mark_as_normalized!(transaction)

        transaction
      rescue => e
        # Marcar como fallido usando el método del modelo
        @raw_data_record.mark_as_failed!(e.message)
        raise
      end

      private

      def validate_data!
        required_fields = [ :num_refer, :fecha, :matricula, :total ]
        missing_fields = required_fields.select { |field| @data[field].blank? }

        if missing_fields.any?
          raise "Missing required fields: #{missing_fields.join(', ')}"
        end
      end

      def create_financial_transaction
        tenant = @raw_data_record.integration_sync_execution.tenant
        config = @raw_data_record.integration_sync_execution.tenant_integration_configuration

        # Parsear fecha desde string YYYYMMDD (ej: '20260107')
        fecha = Date.strptime(@data[:fecha].to_s, "%Y%m%d")

        # Combinar fecha y hora
        transaction_datetime = combine_datetime(fecha, @data[:hora])

        # Calcular descuento total
        discount_amount = (@data[:dcto_fijo].to_f || 0) + (@data[:bonif_total].to_f || 0)

        FinancialTransaction.create!(
          integration_raw_data: @raw_data_record,
          tenant: tenant,
          tenant_integration_configuration: config,
          provider_slug: "solred",
          vehicle_plate: @data[:matricula],
          card_number: @data[:num_tarjeta],
          transaction_date: transaction_datetime,
          location_string: @data[:establecimiento],
          product_code: @data[:cod_producto],
          product_name: @data[:producto],
          quantity: @data[:cantidad].to_f,
          unit_price: @data[:p_unitario].to_f,
          base_amount: @data[:importe].to_f,
          discount_amount: discount_amount,
          total_amount: @data[:total].to_f,
          currency: "EUR",
          status: "pending",
          provider_metadata: {
            num_refer: @data[:num_refer],
            cod_control: @data[:cod_control],
            dcto_fijo: @data[:dcto_fijo],
            bonif_total: @data[:bonif_total]
          }
        )
      end

      def combine_datetime(date, time_str)
        # Parsear hora (formato Solred: "HHMM" ej: "1658")
        if time_str.present? && time_str.to_s.length >= 3
          # Formato HHMM
          time_str = time_str.to_s
          hour = time_str[0..1].to_i
          minute = time_str[2..3].to_i
          second = 0

          DateTime.new(date.year, date.month, date.day, hour, minute, second)
        else
          date.to_datetime
        end
      end
    end
  end
end
