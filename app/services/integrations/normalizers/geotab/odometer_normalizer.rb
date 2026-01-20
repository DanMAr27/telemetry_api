# app/services/integrations/normalizers/geotab/odometer_normalizer.rb
module Integrations
  module Normalizers
    module Geotab
      class OdometerNormalizer < BaseNormalizer
        REQUIRED_FIELDS = %w[dateTime data device.id].freeze

        def normalize(raw_data, config)
          # PASO 1: Validar campos requeridos
          validate_required_fields(raw_data, REQUIRED_FIELDS)

          # PASO 2: Extraer datos
          data = extract_odometer_data(raw_data, config)

          # PASO 3: Actualizar vehículo y crear VehicleKm
          result = update_vehicle_odometer(data, raw_data)

          if result.success?
            ServiceResult.success(
              data: result.data, # Return the VehicleKm object for polymorphic association
              message: "Odómetro actualizado exitosamente"
            )
          else
             ServiceResult.failure(errors: result.errors)
          end
        rescue StandardError => e
          ServiceResult.failure(errors: [ e.message ])
        end

        private

        def extract_odometer_data(raw_data, config)
          date = parse_date(extract_field(raw_data, "dateTime"))
          external_vehicle_id = extract_field(raw_data, "device.id")

          vehicle = map_vehicle(external_vehicle_id, config, event_timestamp: date)

          odometer_meters = extract_field(raw_data, "data")&.to_f
          odometer_km = convert_to_km(odometer_meters)

          {
            vehicle: vehicle,
            odometer_km: odometer_km,
            date: date
          }
        end

        def update_vehicle_odometer(data, raw_data)
          vehicle = data[:vehicle]

          # We need to pass the source_record, but since this is a raw normalizer,
          # we might not have a persisted source record effectively if it checks for IntegrationRawData.
          # However, typically normalizers run on IntegrationRawData.
          # Assuming we might want to link it if possible, but for now we just register the reading.
          # The caller of normalize usually has the IntegrationRawData object but doesn't pass it in `raw_data` directly usually?
          # Actually, `normalize` in `BaseNormalizer` usually takes `raw_data` payload.
          # If we want to link `source_record`, we need to know what it is.
          # For now, we will leave source_record as nil or implement later if we have the object reference.

          VehicleKmManager.new(vehicle).register_reading(
            input_date: data[:date],
            km_reported: data[:odometer_km],
            # source_record: TODO: How to get the source record here?
            # Usually normalizer is called by SyncExecutionService which iterates valid_raw_data.
            # We might need to change signature if we want to pass the raw_data_record.
            # But for now, let's just create the record.
          )
        end

        def convert_to_km(odometer_value)
          return nil if odometer_value.nil?
          (odometer_value / 1000.0).round(2)
        end
      end
    end
  end
end
