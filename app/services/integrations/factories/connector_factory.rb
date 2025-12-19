# app/services/integrations/factories/connector_factory.rb
module Integrations
  module Factories
    class ConnectorFactory
      # Construye el conector apropiado según el slug del proveedor
      #
      # @param provider_slug [String] identificador del proveedor (ej: "geotab")
      # @param config [TenantIntegrationConfiguration] configuración del tenant
      # @return [BaseConnector] instancia del conector específico
      # @raise [ArgumentError] si el proveedor no está implementado

      def self.build(provider_slug, config)
        # Validar que config sea del tipo correcto
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
      # @return [Array<String>] slugs de proveedores disponibles
      def self.available_providers
        [
          "geotab"
          # "verizon_connect",  # Descomentar cuando se implemente
          # "tomtom_telematics", # Descomentar cuando se implemente
          # "samsara"            # Descomentar cuando se implemente
        ]
      end

      # Verificar si un proveedor tiene conector implementado
      # @param provider_slug [String] slug del proveedor
      # @return [Boolean] true si está disponible
      def self.provider_available?(provider_slug)
        available_providers.include?(provider_slug.to_s.downcase)
      end

      # Obtener información sobre proveedores disponibles
      # Útil para mostrar en UI o para debugging
      # @return [Hash] información de cada proveedor
      def self.providers_info
        {
          geotab: {
            name: "Geotab",
            auth_type: "session",
            features: [ "fuel", "battery", "trips" ],
            implemented: true
          },
          verizon_connect: {
            name: "Verizon Connect",
            auth_type: "token",
            features: [ "fuel", "trips" ],
            implemented: false
          },
          tomtom_telematics: {
            name: "TomTom Webfleet",
            auth_type: "basic_auth",
            features: [ "fuel", "trips" ],
            implemented: false
          },
          samsara: {
            name: "Samsara",
            auth_type: "oauth2",
            features: [ "fuel", "battery", "trips" ],
            implemented: false
          }
        }
      end
    end
  end
end
