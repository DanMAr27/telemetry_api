# app/services/financial/matching_service.rb
module Financial
  class MatchingService
    def initialize(financial_transaction, vehicle)
      @transaction = financial_transaction
      @vehicle = vehicle
      @energy_type = ProductClassificationService.classify(@transaction)
    end

    def find_best_match
      # No conciliar "otros" (peajes, lavados, etc.)
      return nil if @energy_type == "other"

      # Buscar candidatos según tipo de energía
      candidates = find_candidates
      return nil if candidates.empty?

      # Calcular scores para cada candidato
      scored_candidates = score_candidates(candidates)

      # Retornar mejor match si supera umbral mínimo (60%)
      best = scored_candidates.max_by { |c| c[:confidence] }
      best if best && best[:confidence] >= 60
    end

    private

    def find_candidates
      case @energy_type
      when "fuel"
        find_refueling_candidates
      when "electric"
        find_electric_charge_candidates
      end
    end

    def find_refueling_candidates
      VehicleRefueling
        .where(vehicle: @vehicle)
        .where(refueling_date: time_window)
        .where(financial_transaction_id: nil) # Solo no conciliados
    end

    def find_electric_charge_candidates
      VehicleElectricCharge
        .where(vehicle: @vehicle)
        .where(charge_start_time: time_window)
        .where(financial_transaction_id: nil)
    end

    def time_window
      # Ventana de ±2 horas alrededor de la transacción
      (@transaction.transaction_date - 2.hours)..(@transaction.transaction_date + 2.hours)
    end

    def score_candidates(candidates)
      candidates.map do |candidate|
        {
          record: candidate,
          record_type: @energy_type,  # Añadir tipo para linking correcto
          confidence: calculate_confidence(candidate)
        }
      end
    end

    def calculate_confidence(record)
      score = 100.0

      # Penalizar diferencia de tiempo (máximo 2 horas = 120 min)
      time_diff = (get_record_date(record) - @transaction.transaction_date).abs / 60.0 # minutos
      time_penalty = (time_diff / 120.0) * 30 # Hasta 30 puntos de penalización
      score -= time_penalty

      # Penalizar diferencia de cantidad
      qty_diff = (get_record_quantity(record) - @transaction.quantity).abs
      qty_percent = (qty_diff / @transaction.quantity) * 100
      qty_penalty = [ qty_percent, 40 ].min # Hasta 40 puntos de penalización
      score -= qty_penalty

      [ score, 0 ].max.round(2)
    end

    # ... (skipping unchanged lines)

    def get_record_date(record)
      case @energy_type
      when "fuel"
        record.refueling_date
      when "electric"
        record.charge_start_time
      end
    end

    def get_record_quantity(record)
      case @energy_type
      when "fuel"
        record.volume_liters # litros (wait, VehicleRefueling has volume_liters)
      when "electric"
        record.energy_consumed_kwh # kWh
      end
    end
  end
end
