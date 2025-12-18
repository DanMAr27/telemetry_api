# app/services/integrations/normalizers/geotab/electric_charge_normalizer.rb
module Integrations
  module Normalizers
    module Geotab
      class ElectricChargeNormalizer < BaseNormalizer
        REQUIRED_FIELDS = %w[startTime duration device.id].freeze

        def normalize(raw_data, config)
          validate_required_fields(raw_data, REQUIRED_FIELDS)

          data = extract_charge_data(raw_data, config)
          charge = create_charge_record(data, raw_data, config)

          ServiceResult.success(data: charge)
        rescue StandardError => e
          ServiceResult.failure(errors: [ e.message ])
        end

        private

        def extract_charge_data(raw_data, config)
          external_vehicle_id = extract_field(raw_data, "device.id")
          vehicle = map_vehicle(external_vehicle_id, config)

          start_time = parse_date(extract_field(raw_data, "startTime"))
          duration_str = extract_field(raw_data, "duration") # "03:28:33.258"
          duration_minutes = parse_duration_to_minutes(duration_str)

          {
            vehicle: vehicle,
            charge_start_time: start_time,
            charge_end_time: start_time + duration_minutes.minutes,
            duration_minutes: duration_minutes,
            location_lat: extract_field(raw_data, "location.y"),
            location_lng: extract_field(raw_data, "location.x"),
            charge_type: extract_field(raw_data, "chargeType"),
            start_soc_percent: extract_field(raw_data, "startStateOfCharge")&.to_f,
            end_soc_percent: extract_field(raw_data, "endStateOfCharge")&.to_f,
            energy_consumed_kwh: extract_field(raw_data, "energyConsumedKwh")&.to_f,
            peak_power_kw: extract_field(raw_data, "peakPowerKw")&.to_f,
            odometer_km: convert_to_km(extract_field(raw_data, "chargingStartedOdometerKm")),
            is_estimated: extract_field(raw_data, "chargeIsEstimated") || false,
            max_ac_voltage: extract_field(raw_data, "maxACVoltage")&.to_i,
            provider_metadata: build_metadata(raw_data)
          }
        end

        def create_charge_record(data, raw_data, config)
          VehicleElectricCharge.create!(
            tenant: config.tenant,
            vehicle: data[:vehicle],
            integration_raw_data: raw_data,
            charge_start_time: data[:charge_start_time],
            charge_end_time: data[:charge_end_time],
            duration_minutes: data[:duration_minutes],
            location_lat: data[:location_lat],
            location_lng: data[:location_lng],
            charge_type: data[:charge_type],
            start_soc_percent: data[:start_soc_percent],
            end_soc_percent: data[:end_soc_percent],
            energy_consumed_kwh: data[:energy_consumed_kwh],
            peak_power_kw: data[:peak_power_kw],
            odometer_km: data[:odometer_km],
            is_estimated: data[:is_estimated],
            max_ac_voltage: data[:max_ac_voltage],
            provider_metadata: data[:provider_metadata]
          )
        end

        def parse_duration_to_minutes(duration_str)
          # "03:28:33.258" → 208 minutos
          return nil if duration_str.blank?

          parts = duration_str.split(":")
          hours = parts[0].to_i
          minutes = parts[1].to_i

          (hours * 60) + minutes
        end

        def convert_to_km(value)
          value&.to_f
        end

        def build_metadata(raw_data)
          {
            measured_onboard_charger_energy_in: extract_field(raw_data, "measuredOnBoardChargerEnergyInKwh"),
            measured_battery_energy_in: extract_field(raw_data, "measuredBatteryEnergyInKwh"),
            version: extract_field(raw_data, "version")
          }.compact
        end
      end
    end
  end
end
