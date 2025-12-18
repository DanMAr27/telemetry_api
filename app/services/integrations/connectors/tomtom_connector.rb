# app/services/integrations/connectors/tomtom_connector.rb
module Integrations
  module Connectors
    class TomtomConnector < BaseConnector
      def authenticate(credentials)
        # TODO: Implementar autenticación con TomTom Telematics
        Rails.logger.info("Mock: Autenticando con TomTom")
        {
          success: true,
          session_id: "tomtom_mock_session_#{SecureRandom.hex(8)}"
        }
      end

      def fetch_refuelings(session_id, from_date, to_date)
        # TODO: Implementar fetch de TomTom
        Rails.logger.info("Mock: Obteniendo repostajes de TomTom")
        []
      end

      def fetch_electric_charges(session_id, from_date, to_date)
        # TODO: Implementar fetch de TomTom
        Rails.logger.info("Mock: Obteniendo cargas de TomTom")
        []
      end

      def fetch_trips(session_id, from_date, to_date)
        # TODO: Implementar fetch de TomTom
        Rails.logger.info("Mock: Obteniendo viajes de TomTom")
        []
      end

      def test_connection(credentials)
        {
          success: true,
          message: "TomTom Telematics (Mock) - Conexión simulada exitosa"
        }
      end
    end
  end
end
