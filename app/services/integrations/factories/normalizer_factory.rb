# app/services/integrations/factories/normalizer_factory.rb
module Integrations
  module Factories
    class NormalizerFactory
      def self.build(provider_slug, feature_key)
        case provider_slug
        when "geotab"
          build_geotab_normalizer(feature_key)
        when "verizon_connect"
          build_verizon_normalizer(feature_key)
        when "tomtom_telematics"
          build_tomtom_normalizer(feature_key)
        else
          raise ArgumentError, "Normalizador no implementado para: #{provider_slug}"
        end
      end

      private

      def self.build_geotab_normalizer(feature_key)
        case feature_key
        when "fuel"
          Normalizers::Geotab::RefuelingNormalizer.new
        when "battery"
          Normalizers::Geotab::ElectricChargeNormalizer.new
        when "trips"
          Normalizers::Geotab::TripNormalizer.new
        when "odometer"
          Normalizers::Geotab::OdometerNormalizer.new
        else
          raise ArgumentError, "Feature no soportada para Geotab: #{feature_key}"
        end
      end

      def self.build_verizon_normalizer(feature_key)
        # TODO: Implementar normalizadores de Verizon
        raise NotImplementedError, "Normalizadores de Verizon pendientes"
      end

      def self.build_tomtom_normalizer(feature_key)
        # TODO: Implementar normalizadores de TomTom
        raise NotImplementedError, "Normalizadores de TomTom pendientes"
      end
    end
  end
end
