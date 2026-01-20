# app/services/integrations/connectors/geotab_connector.rb
module Integrations
  module Connectors
    class GeotabConnector < BaseConnector
      API_BASE_URL = "https://my.geotab.com/apiv1"
      SESSION_TTL = 2.hours

      def initialize(config)
        super(config)

        @session_id = nil
        @database = nil
        @user_name = nil
      end

      def authenticate
        Rails.logger.info("→ Autenticando con Geotab...")

        payload = {
          method: "Authenticate",
          params: {
            userName: credentials["username"],
            password: credentials["password"],
            database: credentials["database"]
          }
        }

        begin
          response = http_post(API_BASE_URL, payload)

          # Validar respuesta
          unless response["result"]&.dig("credentials")
            Rails.logger.error("✗ Respuesta de autenticación inválida")
            raise AuthenticationError, "Respuesta de autenticación inválida"
          end

          # Extraer datos de sesión
          credentials_data = response["result"]["credentials"]

          @session_id = credentials_data["sessionId"]
          @database = credentials_data["database"]
          @user_name = credentials_data["userName"]

          # Guardar en cache
          cache_session

          Rails.logger.info("✓ Geotab autenticado exitosamente")
          Rails.logger.info("  Database: #{@database}")
          Rails.logger.info("  User: #{@user_name}")
          Rails.logger.info("  Session: #{@session_id[0..10]}...")

          true

        rescue AuthenticationError
          raise
        rescue StandardError => e
          Rails.logger.error("✗ Error en autenticación Geotab: #{e.message}")
          raise AuthenticationError, "Error de conexión: #{e.message}"
        end
      end

      def authenticated?
        # Si ya tenemos sessionId en memoria, estamos autenticados
        return true if @session_id.present?

        # Intentar cargar desde cache
        load_from_cache
      end

      def auth_headers
        {}
      end

      def fetch_refuelings(from_date, to_date)
        Rails.logger.info("→ Obteniendo repostajes de Geotab...")
        Rails.logger.info("  Rango: #{from_date} → #{to_date}")

        payload = build_get_payload(
          type_name: "FillUp",
          from_date: from_date,
          to_date: to_date
        )

        response = http_post(API_BASE_URL, payload)
        handle_geotab_response(response, "FillUp")
      end

      def fetch_electric_charges(from_date, to_date)
        Rails.logger.info("→ Obteniendo cargas eléctricas de Geotab...")
        Rails.logger.info("  Rango: #{from_date} → #{to_date}")

        payload = build_get_payload(
          type_name: "ChargeEvent",
          from_date: from_date,
          to_date: to_date
        )

        response = http_post(API_BASE_URL, payload)
        handle_geotab_response(response, "ChargeEvent")
      end

      def fetch_trips(from_date, to_date)
        Rails.logger.info("→ Obteniendo viajes de Geotab...")
        Rails.logger.info("  Rango: #{from_date} → #{to_date}")

        payload = build_get_payload(
          type_name: "Trip",
          from_date: from_date,
          to_date: to_date
        )

        response = http_post(API_BASE_URL, payload)
        handle_geotab_response(response, "Trip")
      end

      def fetch_odometer_readings(from_date, to_date)
        Rails.logger.info("→ Obteniendo lecturas de odómetro de Geotab (StatusData)...")
        Rails.logger.info("  Rango: #{from_date} → #{to_date}")

        payload = build_get_payload(
          type_name: "StatusData",
          from_date: from_date,
          to_date: to_date,
          additional_search: { diagnosticSearch: { id: "DiagnosticOdometerId" } }
        )

        response = http_post(API_BASE_URL, payload)

        # Obtener todos los resultados crudos
        all_results = handle_geotab_response(response, "StatusData (Odometer)")

        # Filtrar para dejar solo el último por día por dispositivo
        filter_last_daily_reading(all_results)
      end

      protected

      def clear_authentication_state
        @session_id = nil
        @database = nil
        @user_name = nil
        Rails.cache.delete(cache_key)

        Rails.logger.info("✓ Estado de autenticación limpiado")
      end

      private

      # Construir payload estándar para método Get de Geotab
      # Todos los requests de datos siguen esta estructura
      def build_get_payload(type_name:, from_date:, to_date:, additional_search: {})
        {
          method: "Get",
          params: {
            typeName: type_name,
            search: {
              FromDate: format_geotab_date(from_date),
              ToDate: format_geotab_date(to_date)
            }.merge(additional_search),
            credentials: build_credentials
          },
          id: generate_request_id,
          jsonrpc: "2.0"
        }
      end

      # Construir objeto credentials para requests
      # TODOS los requests a Geotab (excepto Authenticate) requieren esto
      def build_credentials
        {
          database: @database,
          userName: @user_name,
          sessionId: @session_id
        }
      end

      def cache_key
        "geotab_session_#{@config.id}"
      end

      def cache_session
        session_data = {
          session_id: @session_id,
          database: @database,
          user_name: @user_name
        }

        Rails.cache.write(
          cache_key,
          session_data,
          expires_in: SESSION_TTL
        )

        Rails.logger.debug("✓ Sesión cacheada (TTL: #{SESSION_TTL / 60} min)")
      end

      def load_from_cache
        cached = Rails.cache.read(cache_key)
        return false unless cached.is_a?(Hash)

        cached = cached.with_indifferent_access

        @session_id = cached[:session_id]
        @database = cached[:database]
        @user_name = cached[:user_name]

        return false if @session_id.blank? || @database.blank?

        Rails.logger.debug("✓ Sesión cargada desde cache")
        true
      rescue => e
        Rails.logger.warn("⚠ Error al cargar cache: #{e.message}")
        false
      end

      def handle_geotab_response(response, entity_type)
        # Caso 1: Error de Geotab
        if response["error"]
          error_msg = response["error"]["message"]

          # Si es error de autenticación, limpiar estado y re-lanzar
          if error_msg.match?(/invalid credentials|session|unauthorized/i)
            Rails.logger.warn("⚠ Sesión inválida, limpiando estado...")
            clear_authentication_state
            raise AuthenticationError, "Sesión expirada: #{error_msg}"
          end

          # Otro tipo de error
          raise ApiError, "Geotab error: #{error_msg}"
        end

        # Caso 2: Respuesta exitosa
        result = response["result"] || []

        Rails.logger.info("✓ #{result.count} registros de #{entity_type} obtenidos")

        result
      end

      # Formatear fecha al formato ISO 8601 con milisegundos
      # Geotab requiere: "2025-01-15T10:30:00.000Z"
      def format_geotab_date(date)
        date = Time.zone.parse(date.to_s) unless date.is_a?(Time)
        date.utc.iso8601(3)
      end

      def generate_request_id
        SecureRandom.uuid
      end

      def filter_last_daily_reading(results)
        return [] if results.empty?

        # Agrupar por device.id
        by_device = results.group_by { |r| r.dig("device", "id") }

        filtered_results = []

        by_device.each do |device_id, device_records|
           # Agrupar por fecha (YYYY-MM-DD)
           # dateTime viene como "2025-01-03T15:01:01.496Z"
           by_day = device_records.group_by { |r| r["dateTime"][0..9] }

           by_day.each do |day, day_records|
             # Tomar el último registro del día (mayor dateTime)
             latest_record = day_records.max_by { |r| r["dateTime"] }
             filtered_results << latest_record if latest_record
           end
        end

        Rails.logger.info("✓ Filtrado de odómetros: #{results.count} recibidos -> #{filtered_results.count} retenidos (último diario)")

        filtered_results
      end
    end
  end
end
