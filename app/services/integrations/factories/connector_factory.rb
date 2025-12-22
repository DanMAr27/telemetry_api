# app/services/integrations/factories/connector_factory.rb
module Integrations
  module Factories
    class ConnectorFactory
      def self.build(provider_slug, config)
        unless config.is_a?(TenantIntegrationConfiguration)
          raise ArgumentError, "config debe ser TenantIntegrationConfiguration"
        end

        # Validar que config esté activa
        unless config.is_active
          raise ArgumentError, "La configuración no está activa"
        end

        # Construir conector según el proveedor
        case provider_slug.to_s.downcase
        when "geotab"
          Connectors::GeotabConnector.new(config)

        when "verizon_connect"
          # TODO: Implementar en el futuro
          Connectors::VerizonConnector.new(config)

        when "tomtom_telematics"
          # TODO: Implementar en el futuro
          Connectors::TomtomConnector.new(config)

        when "samsara"
          # TODO: Implementar en el futuro
          Connectors::SamsaraConnector.new(config)

        else
          # Proveedor no soportado
          raise ArgumentError,
                "Conector no implementado para proveedor: '#{provider_slug}'. " \
                "Proveedores disponibles: #{available_providers.join(', ')}"
        end

      rescue NameError => e
        # Si la clase del conector no existe
        Rails.logger.error("Error al construir conector: #{e.message}")
        raise ArgumentError,
              "Conector para '#{provider_slug}' no está implementado aún"
      end

      # Lista de proveedores que tienen conector implementado
      def self.available_providers
        [
          "geotab"
          # "verizon_connect",
          # "tomtom_telematics",
          # "samsara"
        ]
      end

      # Verificar si un proveedor tiene conector implementado
      def self.provider_available?(provider_slug)
        available_providers.include?(provider_slug.to_s.downcase)
      end
    end
  end
end
