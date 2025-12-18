# app/services/integrations/connectors/base_connector.rb
module Integrations
  module Connectors
    class BaseConnector
      # Tiempo máximo de espera para requests HTTP
      REQUEST_TIMEOUT = 30.seconds

      # Métodos abstractos que deben implementar las subclases
      def authenticate(credentials)
        raise NotImplementedError, "Subclases deben implementar #authenticate"
      end

      def fetch_refuelings(session_id, from_date, to_date)
        raise NotImplementedError, "Subclases deben implementar #fetch_refuelings"
      end

      def fetch_electric_charges(session_id, from_date, to_date)
        raise NotImplementedError, "Subclases deben implementar #fetch_electric_charges"
      end

      def fetch_trips(session_id, from_date, to_date)
        raise NotImplementedError, "Subclases deben implementar #fetch_trips"
      end

      protected
      # Realizar petición POST
      def http_post(url, body, headers = {})
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.read_timeout = REQUEST_TIMEOUT
        http.open_timeout = REQUEST_TIMEOUT

        request = Net::HTTP::Post.new(uri.path, default_headers.merge(headers))
        request.body = body.to_json

        log_request(url, body)

        response = http.request(request)

        log_response(response)

        parse_response(response)
      end

      # Realizar petición GET
      def http_get(url, headers = {})
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.read_timeout = REQUEST_TIMEOUT
        http.open_timeout = REQUEST_TIMEOUT

        request = Net::HTTP::Get.new(uri.request_uri, default_headers.merge(headers))

        log_request(url, nil)

        response = http.request(request)

        log_response(response)

        parse_response(response)
      end

      # Headers por defecto
      def default_headers
        {
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
      end

      # Parsear respuesta HTTP
      def parse_response(response)
        case response.code.to_i
        when 200..299
          JSON.parse(response.body)
        when 401
          raise AuthenticationError, "Error de autenticación: #{response.body}"
        when 429
          raise RateLimitError, "Límite de peticiones excedido"
        when 500..599
          raise ServerError, "Error del servidor: #{response.code}"
        else
          raise ApiError, "Error HTTP #{response.code}: #{response.body}"
        end
      rescue JSON::ParserError => e
        raise ApiError, "Respuesta no es JSON válido: #{e.message}"
      end

      def log_request(url, body)
        Rails.logger.debug("→ #{self.class.name} POST #{url}")
        Rails.logger.debug("  Body: #{body.to_json[0..200]}...") if body
      end

      def log_response(response)
        Rails.logger.debug("← Response: #{response.code}")
        Rails.logger.debug("  Body: #{response.body[0..200]}...")
      end

      class ApiError < StandardError; end
      class AuthenticationError < ApiError; end
      class RateLimitError < ApiError; end
      class ServerError < ApiError; end
    end
  end
end
