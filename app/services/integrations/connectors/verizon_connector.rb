# app/services/integrations/connectors/verizon_connector.rb
module Integrations
  module Connectors
    class VerizonConnector < BaseConnector
      def authenticate(credentials)
        # TODO: Implementar autenticación con Verizon Connect
        Rails.logger.info("Mock: Autenticando con Verizon Connect")
        {
          success: true,
          session_id: "verizon_mock_session_#{SecureRandom.hex(8)}"
        }
      end

      def fetch_refuelings(session_id, from_date, to_date)
        # TODO: Implementar fetch de Verizon
        Rails.logger.info("Mock: Obteniendo repostajes de Verizon")
        []
      end

      def fetch_electric_charges(session_id, from_date, to_date)
        # TODO: Implementar fetch de Verizon
        Rails.logger.info("Mock: Obteniendo cargas de Verizon")
        []
      end

      def fetch_trips(session_id, from_date, to_date)
        # TODO: Implementar fetch de Verizon
        Rails.logger.info("Mock: Obteniendo viajes de Verizon")
        []
      end

      def test_connection(credentials)
        {
          success: true,
          message: "Verizon Connect (Mock) - Conexión simulada exitosa"
        }
      end
    end
  end
end
