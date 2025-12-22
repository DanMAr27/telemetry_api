# app/services/integrations/normalizers/base_normalizer.rb
module Integrations
  module Normalizers
    class BaseNormalizer
      def normalize(raw_data, config)
        raise NotImplementedError, "Subclases deben implementar #normalize"
      end

      protected

      # Mapear external_vehicle_id a vehicle_id de nuestra BD
      def map_vehicle(external_vehicle_id, config)
        mapping = VehicleProviderMapping.find_by(
          tenant_integration_configuration: config,
          external_vehicle_id: external_vehicle_id,
          is_active: true
        )

        unless mapping
          raise "Vehicle mapping not found for external_id: #{external_vehicle_id}"
        end

        mapping.vehicle
      end

      # Extraer valor de un campo del raw_data
      def extract_field(raw_data, field_path)
        # Soporta paths anidados: 'device.id', 'location.x'
        fields = field_path.split(".")
        value = raw_data.raw_data

        fields.each do |field|
          value = value[field] || value[field.to_sym]
          return nil if value.nil?
        end

        value
      end

      # Parsear fecha del proveedor
      def parse_date(date_string)
        return nil if date_string.blank?
        Time.zone.parse(date_string)
      rescue ArgumentError => e
        Rails.logger.warn("Error al parsear fecha '#{date_string}': #{e.message}")
        nil
      end

      # Validar que campos requeridos existan
      def validate_required_fields(raw_data, required_fields)
        missing = required_fields.select { |field| extract_field(raw_data, field).nil? }

        if missing.any?
          raise "Campos requeridos faltantes: #{missing.join(', ')}"
        end
      end
    end
  end
end
