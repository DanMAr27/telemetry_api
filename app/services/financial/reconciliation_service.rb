# app/services/financial/reconciliation_service.rb
module Financial
  class ReconciliationService
    def initialize(tenant_integration_configuration, transactions_scope = nil)
      @config = tenant_integration_configuration
      @tenant = @config.tenant
      @transactions_scope = transactions_scope
      @stats = {
        processed: 0,
        matched: 0,
        unmatched: 0,
        ignored: 0
      }
    end

    def call
      # Obtener transacciones pendientes de conciliar
      # Si se pasó un scope manual, usarlo directamente
      transactions_to_process = if @transactions_scope
        @transactions_scope
      else
        # Modo automático: solo pendientes
        FinancialTransaction
          .where(tenant_integration_configuration: @config)
          .where(status: :pending)
      end

      transactions_to_process.each do |transaction|
        reconcile_transaction(transaction)
      end

      @stats
    end

    private

    def reconcile_transaction(transaction)
      # 1. Clasificar producto
      energy_type = ProductClassificationService.classify(transaction)

      # No conciliar "otros" (peajes, lavados, etc.)
      if energy_type == "other"
        transaction.update!(status: :ignored)
        @stats[:ignored] += 1
        @stats[:processed] += 1
        return
      end

      # 2. Identificar vehículo
      vehicle = VehicleMappingService.find_vehicle(transaction)

      if vehicle.nil?
        handle_unidentified_vehicle(transaction)
        return
      end

      # 3. Buscar match
      matcher = MatchingService.new(transaction, vehicle)
      match = matcher.find_best_match

      if match
        link_transaction_to_record(transaction, match)
        @stats[:matched] += 1
      else
        # Vehículo identificado pero sin telemetría
        # Vehículo identificado pero sin telemetría
        transaction.update!(
          status: :unmatched,
          reconciliation_metadata: { match_reason: "no_telemetry_found" }
        )
        @stats[:unmatched] += 1
      end

      @stats[:processed] += 1

    rescue => e
      Rails.logger.error("Error reconciling transaction #{transaction.id}: #{e.message}")
      @stats[:unmatched] += 1
      @stats[:processed] += 1

      # Persistir error como unmatched y guardar detalles en metadata
      transaction.update!(
        status: :unmatched,
        reconciliation_metadata: {
          match_reason: "reconciliation_error",
          error_message: e.message,
          error_trace: e.backtrace&.first(3)
        }
      )
    end

    def handle_unidentified_vehicle(transaction)
      # Marcar como unmatched con razón específica
      transaction.update!(
        status: :unmatched,
        reconciliation_metadata: {
          match_reason: "vehicle_not_identified",
          attempted_plate: transaction.vehicle_plate,
          attempted_card: transaction.card_number
        }
      )

      @stats[:unmatched] += 1
      @stats[:processed] += 1

      # Registrar en metadata de sync_execution para alertas
      log_unidentified_vehicle(transaction)
    end

    def log_unidentified_vehicle(transaction)
      execution = transaction.integration_raw_data&.integration_sync_execution
      return unless execution

      unidentified = execution.metadata["unidentified_vehicles"] || []
      unidentified << {
        transaction_id: transaction.id,
        plate: transaction.vehicle_plate,
        card: transaction.card_number,
        external_id: transaction.integration_raw_data&.external_id
      }

      execution.update!(
        metadata: execution.metadata.merge("unidentified_vehicles" => unidentified)
      )
    end

    def link_transaction_to_record(transaction, match)
      record = match[:record]
      record_type = match[:record_type]

      ActiveRecord::Base.transaction do
        # Actualizar transacción
        # Actualizar transacción
        transaction.update!(
          status: :matched,
          match_confidence: 100,
          reconciliation_metadata: {
            match_details: {
              time_diff_seconds: match[:time_diff],
              quantity_diff_percent: match[:quantity_diff],
              matched_by: "auto",
              energy_type: record_type
            }
          }
        )

        # Vincular según tipo
        case record_type
        when "fuel"
          link_to_refueling(transaction, record)
        when "electric"
          link_to_electric_charge(transaction, record)
        end
      end
    end

    def link_to_refueling(transaction, refueling)
      transaction.update!(vehicle_refueling: refueling)

      refueling.update!(
        financial_transaction: transaction,
        cost: transaction.total_amount,
        currency: transaction.currency,
        is_reconciled: true
      )
    end

    def link_to_electric_charge(transaction, charge)
      transaction.update!(vehicle_electric_charge: charge)

      charge.update!(
        financial_transaction: transaction,
        cost: transaction.total_amount,
        currency: transaction.currency,
        is_reconciled: true
      )
    end
  end
end
