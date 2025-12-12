# app/services/telemetry/provider_registry.rb
module Telemetry
  class ProviderRegistry
    class << self
      # Registro de connectors
      def connectors
        @connectors ||= {}
      end

      # Registro de normalizers
      def normalizers
        @normalizers ||= {}
      end

      # Registrar un proveedor completo
      def register(provider_slug, connector_class:, normalizer_class:)
        connectors[provider_slug.to_s] = connector_class
        normalizers[provider_slug.to_s] = normalizer_class
      end

      # Obtener connector para un proveedor
      def connector_for(provider_slug)
        connector_class = connectors[provider_slug.to_s]
        raise UnknownProviderError, "No connector registered for '#{provider_slug}'" unless connector_class
        connector_class
      end

      # Obtener normalizer para un proveedor
      def normalizer_for(provider_slug)
        normalizer_class = normalizers[provider_slug.to_s]
        raise UnknownProviderError, "No normalizer registered for '#{provider_slug}'" unless normalizer_class
        normalizer_class
      end

      # Verificar si un proveedor está registrado
      def registered?(provider_slug)
        connectors.key?(provider_slug.to_s) && normalizers.key?(provider_slug.to_s)
      end

      # Listar proveedores registrados
      def registered_providers
        connectors.keys & normalizers.keys
      end

      # Instanciar connector con credenciales
      def build_connector(provider_slug, credentials)
        connector_class = connector_for(provider_slug)
        connector_class.new(credentials)
      end

      # Instanciar normalizer
      def build_normalizer(provider_slug)
        normalizer_class = normalizer_for(provider_slug)
        normalizer_class.new
      end
    end

    class UnknownProviderError < StandardError; end
  end
end

# Registrar proveedores existentes
# Este código se ejecuta al cargar Rails
Telemetry::ProviderRegistry.register(
  "geotab",
  connector_class: Telemetry::Connectors::GeotabConnector,
  normalizer_class: Telemetry::Normalizers::GeotabNormalizer
)

# Cuando añadas nuevos proveedores, solo agrégalos aquí:
# Telemetry::ProviderRegistry.register(
#   'verizon_connect',
#   connector_class: Telemetry::Connectors::VerizonConnector,
#   normalizer_class: Telemetry::Normalizers::VerizonNormalizer
# )
