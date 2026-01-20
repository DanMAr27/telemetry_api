# app/services/integrations/connectors/base_connector.rb
module Integrations
  module Connectors
    class BaseConnector
      REQUEST_TIMEOUT = 30.seconds

      attr_reader :config

      def initialize(config)
        @config = config
      end

      def fetch_data(feature_key, from_date, to_date)
        # PASO 1: Asegurar autenticación válida
        ensure_authenticated!

        # PASO 2: Llamar al método específico según la feature
        case feature_key
        when "fuel"
          fetch_refuelings(from_date, to_date)
        when "battery"
          fetch_electric_charges(from_date, to_date)
        when "trips"
          fetch_trips(from_date, to_date)
        when "odometer"
          fetch_odometer_readings(from_date, to_date)
        else
          raise ArgumentError, "Feature no soportada: #{feature_key}"
        end
      rescue AuthenticationError => e
        # Si falla autenticación, limpiar estado y re-lanzar
        Rails.logger.error("Authentication failed: #{e.message}")
        clear_authentication_state
        raise
      rescue StandardError => e
        Rails.logger.error("Error fetching data: #{e.class} - #{e.message}")
        raise ApiError, "Error obteniendo datos: #{e.message}"
      end

      # Proceso de autenticación específico del proveedor
      def authenticate
        raise NotImplementedError, "#{self.class} debe implementar #authenticate"
      end

      # Verificar si hay autenticación válida
      def authenticated?
        raise NotImplementedError, "#{self.class} debe implementar #authenticated?"
      end

      # Headers de autenticación para requests HTTP
      def auth_headers
        {}
      end

      # Obtener repostajes en el rango de fechas
      def fetch_refuelings(from_date, to_date)
        raise NotImplementedError, "#{self.class} debe implementar #fetch_refuelings"
      end

      # Obtener cargas eléctricas en el rango de fechas
      def fetch_electric_charges(from_date, to_date)
        raise NotImplementedError, "#{self.class} debe implementar #fetch_electric_charges"
      end

      # Obtener viajes en el rango de fechas
      def fetch_trips(from_date, to_date)
        raise NotImplementedError, "#{self.class} debe implementar #fetch_trips"
      end

      # Obtener lecturas de odómetro en el rango de fechas
      def fetch_odometer_readings(from_date, to_date)
        raise NotImplementedError, "#{self.class} debe implementar #fetch_odometer_readings"
      end

      protected

      # Asegura que hay autenticación válida antes de hacer requests
      def ensure_authenticated!
        return if authenticated?

        Rails.logger.info("→ Autenticación requerida para #{self.class.name}")
        authenticate

        unless authenticated?
          raise AuthenticationError, "Falló la autenticación"
        end
      end

      # Limpiar estado de autenticación (útil cuando expira)
      def clear_authentication_state
        # Las subclases pueden sobrescribir esto para limpiar su estado
        Rails.logger.info("Clearing authentication state")
      end

      # Acceso rápido a las credenciales
      def credentials
        @config.credentials
      end

      # Realizar petición POST
      def http_post(url, body, headers = {})
        uri = URI.parse(url)
        http = build_http_client(uri)

        request = Net::HTTP::Post.new(uri.path, default_headers.merge(headers))
        request.body = body.to_json

        log_request(:POST, url, body)

        response = http.request(request)

        log_response(response)

        parse_response(response)
      end

      # Realizar petición GET
      def http_get(url, headers = {})
        uri = URI.parse(url)
        http = build_http_client(uri)

        request = Net::HTTP::Get.new(uri.request_uri, default_headers.merge(headers))

        log_request(:GET, url, nil)

        response = http.request(request)

        log_response(response)

        parse_response(response)
      end

      private

      # Construir cliente HTTP con configuración común
      def build_http_client(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.read_timeout = REQUEST_TIMEOUT
        http.open_timeout = REQUEST_TIMEOUT
        http
      end

      def default_headers
        {
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "User-Agent" => "FleetManager/1.0"
        }
      end

      # Parsear respuesta HTTP
      def parse_response(response)
        case response.code.to_i
        when 200..299
          # Respuesta exitosa
          JSON.parse(response.body)
        when 401, 403
          # Error de autenticación
          raise AuthenticationError, "Error de autenticación: #{response.body}"
        when 429
          # Rate limit
          raise RateLimitError, "Límite de peticiones excedido"
        when 500..599
          # Error del servidor
          raise ServerError, "Error del servidor (#{response.code}): #{response.body}"
        else
          # Otro error
          raise ApiError, "Error HTTP #{response.code}: #{response.body}"
        end
      rescue JSON::ParserError => e
        raise ApiError, "Respuesta no es JSON válido: #{e.message}"
      end

      # Logging de requests
      def log_request(method, url, body)
        Rails.logger.debug("→ #{self.class.name} #{method} #{url}")
        if body && body.is_a?(Hash)
          # Ocultar contraseñas en logs
          safe_body = body.deep_dup
          safe_body.dig("params", "password")&.replace("******") if safe_body.dig("params", "password")
          Rails.logger.debug("  Body: #{safe_body.to_json[0..200]}...")
        end
      end

      # Logging de responses
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
