# app/services/integrations/normalizers/geotab/refueling_normalizer.rb
module Integrations
  module Normalizers
    module Geotab
      class RefuelingNormalizer < BaseNormalizer
        # Campos requeridos en el JSON de Geotab
        REQUIRED_FIELDS = %w[dateTime volume device.id].freeze

        def normalize(raw_data, config)
          # PASO 1: Validar campos requeridos
          validate_required_fields(raw_data, REQUIRED_FIELDS)

          # PASO 2: Extraer datos del JSON RAW
          data = extract_refueling_data(raw_data, config)

          # PASO 3: Crear registro en VehicleRefueling
          refueling = create_refueling_record(data, raw_data, config)

          ServiceResult.success(
            data: refueling,
            message: "Repostaje normalizado exitosamente"
          )

        rescue StandardError => e
          ServiceResult.failure(errors: [ e.message ])
        end

        private

        def extract_refueling_data(raw_data, config)
          # Extraer fecha primero para validar mapping temporal
          refueling_date = parse_date(extract_field(raw_data, "dateTime"))

          # Extraer external_vehicle_id
          external_vehicle_id = extract_field(raw_data, "device.id")

          # Mapear a vehicle de nuestra BD usando fecha
          vehicle = map_vehicle(external_vehicle_id, config, event_timestamp: refueling_date)

          # Extraer campos del JSON
          {
            vehicle: vehicle,
            refueling_date: refueling_date,
            volume_liters: extract_field(raw_data, "volume")&.to_f,
            cost: extract_field(raw_data, "cost")&.to_f,
            currency: extract_field(raw_data, "currencyCode")&.strip,
            odometer_km: convert_to_km(extract_field(raw_data, "odometer")),
            location_lat: extract_field(raw_data, "location.y"),
            location_lng: extract_field(raw_data, "location.x"),
            fuel_type: map_fuel_type(extract_field(raw_data, "productType")),
            confidence_level: extract_field(raw_data, "confidence"),
            is_estimated: false, # Geotab marca FillUp como medido
            tank_capacity_liters: extract_tank_capacity(raw_data),
            provider_metadata: build_metadata(raw_data)
          }
        end

        def create_refueling_record(data, raw_data, config)
          VehicleRefueling.create!(
            tenant: config.tenant,
            vehicle: data[:vehicle],
            integration_raw_data: raw_data,
            refueling_date: data[:refueling_date],
            volume_liters: data[:volume_liters],
            cost: data[:cost],
            currency: data[:currency],
            odometer_km: data[:odometer_km],
            location_lat: data[:location_lat],
            location_lng: data[:location_lng],
            fuel_type: data[:fuel_type], # Ahora es una asociación
            confidence_level: data[:confidence_level],
            is_estimated: data[:is_estimated],
            # tank_capacity_liters: data[:tank_capacity_liters], # Removed as per migration? Or kept? Only fuel_type was removed.
            # Checking migration: remove_column :vehicle_refuelings, :fuel_type, :string
            # tank_capacity_liters exists in schema.
            tank_capacity_liters: data[:tank_capacity_liters],
            provider_metadata: data[:provider_metadata]
          )
        end

        def map_fuel_type(raw_type)
          return nil if raw_type.blank?

          # Geotab mapping logic
          case raw_type.to_s.downcase
          when /gasoline|petrol|^g$/
            FuelType.find_by(code: "gasoline")
          when /diesel|^d$/
            FuelType.find_by(code: "diesel")
          when /electric|ev/
            FuelType.find_by(code: "electric")
          when /lpg/
            FuelType.find_by(code: "lpg")
          when /cng/
            FuelType.find_by(code: "cng")
          when /adblue/
             FuelType.find_by(code: "adblue")
          else
            # Try to find by direct name match or default to Other if needed,
            # or just return nil to leave it unclassified (nullable FK)
            FuelType.find_by(name: raw_type)
          end
        end
        def convert_to_km(odometer_value)
          return nil if odometer_value.nil?
          # Geotab devuelve odómetro en metros, convertir a km
          (odometer_value.to_f / 1000).round(2)
        end

        def extract_tank_capacity(raw_data)
          capacity = extract_field(raw_data, "tankCapacity.volume")
          capacity&.to_f
        end

        def build_metadata(raw_data)
          {
            distance: extract_field(raw_data, "distance"),
            total_fuel_used: extract_field(raw_data, "totalFuelUsed"),
            derived_volume: extract_field(raw_data, "derivedVolume"),
            version: extract_field(raw_data, "version")
          }.compact
        end
      end
    end
  end
end
