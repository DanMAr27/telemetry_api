# app/services/integrations/factories/connector_factory.rb
module Integrations
  module Factories
    class ConnectorFactory
      # Método estático para construir el conector apropiado
      def self.build(provider_slug)
        case provider_slug
        when "geotab"
          Connectors::GeotabConnector.new
        when "verizon_connect"
          Connectors::VerizonConnector.new
        when "tomtom_telematics"
          Connectors::TomtomConnector.new
        else
          raise ArgumentError, "Conector no implementado para: #{provider_slug}"
        end
      end
    end
  end
end
