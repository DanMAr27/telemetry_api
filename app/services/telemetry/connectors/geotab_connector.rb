# app/services/telemetry/connectors/geotab_connector.rb
module Telemetry
  module Connectors
    class GeotabConnector
      API_BASE_URL = "https://my.geotab.com/apiv1"

      attr_reader :credentials, :session_id, :database

      def initialize(credentials_hash)
        @credentials = credentials_hash.with_indifferent_access
        @session_id = nil
        @database = credentials[:database]
      end

      # Autenticación - Devuelve el session_id
      def authenticate!
        response = make_request(
          method: "Authenticate",
          params: {
            userName: credentials[:userName],
            password: credentials[:password],
            database: credentials[:database]
          }
        )

        raise AuthenticationError, "Authentication failed" unless response["result"]

        @session_id = response.dig("result", "credentials", "sessionId")
        @database = response.dig("result", "credentials", "database")

        @session_id
      end

      # Método genérico para obtener datos de Geotab
      def fetch_data(type_name:, from_date: nil, to_date: nil, search: {})
        ensure_authenticated!

        search_params = search.dup
        search_params[:FromDate] = format_date(from_date) if from_date
        search_params[:ToDate] = format_date(to_date) if to_date

        response = make_request(
          method: "Get",
          params: {
            typeName: type_name,
            search: search_params,
            credentials: auth_credentials
          }
        )

        response["result"] || []
      end

      # Obtener repostajes (FillUp)
      def fetch_fillups(from_date:, to_date: Time.current)
        fetch_data(
          type_name: "FillUp",
          from_date: from_date,
          to_date: to_date
        )
      end

      # Obtener cargas eléctricas (ChargeEvent)
      def fetch_charge_events(from_date:, to_date: Time.current)
        fetch_data(
          type_name: "ChargeEvent",
          from_date: from_date,
          to_date: to_date
        )
      end

      # Obtener dispositivos (para mapeo inicial)
      def fetch_devices
        ensure_authenticated!

        response = make_request(
          method: "Get",
          params: {
            typeName: "Device",
            credentials: auth_credentials
          }
        )

        response["result"] || []
      end

      # Obtener datos de odómetro
      def fetch_odometer_readings(from_date:, to_date: Time.current, device_id: nil)
        search_params = {}
        search_params[:DeviceSearch] = { id: device_id } if device_id

        fetch_data(
          type_name: "StatusData",
          from_date: from_date,
          to_date: to_date,
          search: search_params
        )
      end

      private

      def ensure_authenticated!
        authenticate! unless authenticated?
      end

      def authenticated?
        @session_id.present?
      end

      def auth_credentials
        {
          database: @database,
          userName: credentials[:userName],
          sessionId: @session_id
        }
      end

      def make_request(method:, params:)
        uri = URI(API_BASE_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 120 # 2 minutos timeout

        request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
        request.body = {
          method: method,
          params: params,
          jsonrpc: "2.0",
          id: SecureRandom.random_number(1000)
        }.to_json

        response = http.request(request)

        handle_response(response)
      rescue Net::ReadTimeout => e
        raise TimeoutError, "Geotab API timeout: #{e.message}"
      rescue StandardError => e
        raise ConnectionError, "Geotab API error: #{e.message}"
      end

      def handle_response(response)
        unless response.is_a?(Net::HTTPSuccess)
          raise ApiError, "HTTP #{response.code}: #{response.body}"
        end

        parsed = JSON.parse(response.body)

        if parsed["error"]
          error_message = parsed.dig("error", "message") || "Unknown error"
          raise ApiError, "Geotab API error: #{error_message}"
        end

        parsed
      rescue JSON::ParserError => e
        raise ApiError, "Invalid JSON response: #{e.message}"
      end

      def format_date(date)
        date = date.to_time if date.is_a?(Date)
        date.utc.iso8601(3) # Formato: 2025-01-01T00:00:00.000Z
      end

      # Custom Exceptions
      class GeotabError < StandardError; end
      class AuthenticationError < GeotabError; end
      class ApiError < GeotabError; end
      class TimeoutError < GeotabError; end
      class ConnectionError < GeotabError; end
    end
  end
end
