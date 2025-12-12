# app/services/telemetry/normalizers/geotab_normalizer.rb
module Telemetry
  module Normalizers
    class GeotabNormalizer
      PROVIDER_NAME = "geotab"

      # Normaliza un repostaje de Geotab (FillUp) a nuestro modelo
      def normalize_refuel(raw_fillup, vehicle_id)
        {
          vehicle_id: vehicle_id,
          external_id: raw_fillup["id"],
          provider_name: PROVIDER_NAME,
          refuel_date: parse_datetime(raw_fillup["dateTime"]),
          volume_liters: extract_volume(raw_fillup),
          cost: raw_fillup["cost"].to_f,
          currency_code: raw_fillup["currencyCode"]&.strip,
          location_lat: extract_latitude(raw_fillup),
          location_lng: extract_longitude(raw_fillup),
          odometer_km: convert_meters_to_km(raw_fillup["odometer"]),
          tank_capacity_liters: extract_tank_capacity(raw_fillup),
          distance_since_last_refuel_km: convert_meters_to_km(raw_fillup["distance"]),
          confidence_level: raw_fillup["confidence"],
          product_type: raw_fillup["productType"],
          raw_data: raw_fillup
        }
      end

      # Normaliza una carga eléctrica de Geotab (ChargeEvent) a nuestro modelo
      def normalize_charge_event(raw_charge, vehicle_id)
        {
          vehicle_id: vehicle_id,
          external_id: raw_charge["id"],
          provider_name: PROVIDER_NAME,
          start_time: parse_datetime(raw_charge["startTime"]),
          duration_minutes: parse_duration_minutes(raw_charge["duration"]),
          energy_consumed_kwh: raw_charge["energyConsumedKwh"].to_f,
          start_soc_percent: raw_charge["startStateOfCharge"].to_f,
          end_soc_percent: raw_charge["endStateOfCharge"].to_f,
          charge_type: raw_charge["chargeType"],
          charge_is_estimated: raw_charge["chargeIsEstimated"],
          location_lat: extract_latitude(raw_charge),
          location_lng: extract_longitude(raw_charge),
          odometer_km: raw_charge["chargingStartedOdometerKm"].to_f,
          peak_power_kw: raw_charge["peakPowerKw"].to_f,
          measured_charger_energy_in_kwh: raw_charge["measuredOnBoardChargerEnergyInKwh"].to_f,
          measured_battery_energy_in_kwh: raw_charge["measuredBatteryEnergyInKwh"].to_f,
          raw_data: raw_charge
        }
      end

      # Valida que los datos normalizados sean válidos
      def validate_refuel(normalized_data)
        errors = []

        errors << "Missing external_id" if normalized_data[:external_id].blank?
        errors << "Missing refuel_date" if normalized_data[:refuel_date].blank?
        errors << "Invalid volume" if normalized_data[:volume_liters].present? && normalized_data[:volume_liters] <= 0
        errors << "Invalid cost" if normalized_data[:cost].present? && normalized_data[:cost] < 0

        errors
      end

      def validate_charge_event(normalized_data)
        errors = []

        errors << "Missing external_id" if normalized_data[:external_id].blank?
        errors << "Missing start_time" if normalized_data[:start_time].blank?
        errors << "Invalid energy" if normalized_data[:energy_consumed_kwh].present? && normalized_data[:energy_consumed_kwh] <= 0
        errors << "Invalid SOC range" if invalid_soc_range?(normalized_data)

        errors
      end

      private

      def parse_datetime(datetime_str)
        return nil if datetime_str.blank?
        Time.zone.parse(datetime_str)
      rescue ArgumentError
        nil
      end

      def extract_volume(fillup)
        # Geotab puede devolver 'volume' o 'derivedVolume'
        volume = fillup["volume"] || fillup["derivedVolume"]
        volume.to_f if volume.present?
      end

      def extract_latitude(data)
        data.dig("location", "y")&.to_f
      end

      def extract_longitude(data)
        data.dig("location", "x")&.to_f
      end

      def extract_tank_capacity(fillup)
        fillup.dig("tankCapacity", "volume")&.to_f
      end

      def convert_meters_to_km(meters)
        return nil if meters.blank?
        (meters.to_f / 1000.0).round(2)
      end

      def parse_duration_minutes(duration_str)
        # Formato Geotab: "03:28:33.2580000" (HH:MM:SS.mmmmmmm)
        return nil if duration_str.blank?

        parts = duration_str.split(":")
        hours = parts[0].to_i
        minutes = parts[1].to_i
        seconds = parts[2].to_f

        (hours * 60) + minutes + (seconds / 60.0).round(2)
      rescue StandardError
        nil
      end

      def invalid_soc_range?(data)
        start_soc = data[:start_soc_percent]
        end_soc = data[:end_soc_percent]

        return false if start_soc.blank? || end_soc.blank?

        start_soc < 0 || start_soc > 100 || end_soc < 0 || end_soc > 100
      end
    end
  end
end
