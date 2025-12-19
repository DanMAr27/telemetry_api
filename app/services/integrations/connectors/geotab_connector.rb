# app/services/integrations/connectors/geotab_connector.rb
module Integrations
  module Connectors
    class GeotabConnector < BaseConnector
      API_BASE_URL = "https://my.geotab.com/apiv1"
      SESSION_TTL = 2.hours

      def initialize(config)
        super(config)

        # Estado de la sesión (se carga desde cache o se autentica)
        @session_id = nil
        @database = nil
        @server_path = nil
        @username = nil

        # URL dinámica (cambia después de autenticar)
        @api_url = API_BASE_URL
      end


      # Autenticación con Geotab
      # Geotab usa un sistema de sesiones:
      # 1. Envías user/pass/database
      # 2. Recibes sessionId + server path específico
      # 3. Usas ese sessionId en todos los requests siguientes
      def authenticate
        Rails.logger.info("→ Autenticando con Geotab...")

        # Construir payload de autenticación según API de Geotab
        payload = {
          method: "Authenticate",
          params: {
            userName: credentials["username"],
            password: credentials["password"],
            database: credentials["database"]
          }
        }

        begin
          # Llamar a la API de Geotab
          response = http_post(@api_url, payload)

          # Verificar respuesta exitosa
          if response["result"] && response["result"]["credentials"]
            @session_id = response["result"]["credentials"]["sessionId"]
            @database = response["result"]["credentials"]["database"]
            @user_name = response["result"]["credentials"]["userName"]

            @server_path = response["result"]["path"]

            @api_url = API_BASE_URL

            cache_session

            Rails.logger.info("✓ Geotab autenticado exitosamente")
            Rails.logger.info("  Server: #{@api_url}")
            Rails.logger.info("  Database: #{@database}")
            Rails.logger.info("  Database: #{@user_name}")
            Rails.logger.info("  Session: #{@session_id[0..10]}...")

            true
          else
            # Respuesta inválida
            Rails.logger.error("✗ Respuesta de autenticación inválida")
            raise AuthenticationError, "Respuesta de autenticación inválida"
          end

        rescue AuthenticationError
          # Re-lanzar errores de autenticación
          raise
        rescue StandardError => e
          # Capturar otros errores
          Rails.logger.error("✗ Error en autenticación Geotab: #{e.message}")
          raise AuthenticationError, "Error de conexión: #{e.message}"
        end
      end

      # Verificar si hay sesión válida
      # Intenta cargar desde cache antes de decir que no
      def authenticated?
        # Si ya tenemos sessionId en memoria, estamos autenticados
        return true if @session_id.present?

        # Intentar cargar desde cache
        load_from_cache
      end

      # Geotab no usa headers de autenticación
      # La autenticación va en el body de cada request
      def auth_headers
        {}
      end

      # OBTENCIÓN DE DATOS - REPOSTAJES (FillUp)
      def fetch_refuelings(from_date, to_date)
        Rails.logger.info("→ Obteniendo repostajes de Geotab...")
        Rails.logger.info("  Rango: #{from_date} → #{to_date}")

        # Construir payload según documentación de Geotab
        # https://geotab.github.io/sdk/software/api/reference/#Get1
        payload = {
          method: "Get",
          params: {
            # Tipo de entidad: FillUp (repostajes)
            typeName: "FillUp",

            # Búsqueda por rango de fechas
            search: {
              FromDate: format_geotab_date(from_date),
              ToDate: format_geotab_date(to_date)
            },

            # Credenciales de la sesión actual
            credentials: build_credentials
          },

          # ID único del request (para debugging)
          id: generate_request_id,

          # Versión del protocolo JSON-RPC
          jsonrpc: "2.0"
        }

        # Ejecutar request
        response = http_post(@api_url, payload)

        # Procesar respuesta de Geotab
        handle_geotab_response(response, "FillUp")
      end

      # OBTENCIÓN DE DATOS - CARGAS ELÉCTRICAS (ChargeEvent)
      def fetch_electric_charges(from_date, to_date)
        Rails.logger.info("→ Obteniendo cargas eléctricas de Geotab...")
        Rails.logger.info("  Rango: #{from_date} → #{to_date}")

        payload = {
          method: "Get",
          params: {
            # Tipo de entidad: ChargeEvent (cargas eléctricas)
            typeName: "ChargeEvent",

            search: {
              fromDate: format_geotab_date(from_date),
              toDate: format_geotab_date(to_date)
            },

            credentials: build_credentials
          },

          id: generate_request_id,
          jsonrpc: "2.0"
        }

        response = http_post(@api_url, payload)

        handle_geotab_response(response, "ChargeEvent")
      end

      # OBTENCIÓN DE DATOS - VIAJES (Trip)
      def fetch_trips(from_date, to_date)
        Rails.logger.info("→ Obteniendo viajes de Geotab...")
        Rails.logger.info("  Rango: #{from_date} → #{to_date}")

        payload = {
          method: "Get",
          params: {
            # Tipo de entidad: Trip (viajes)
            typeName: "Trip",

            search: {
              fromDate: format_geotab_date(from_date),
              toDate: format_geotab_date(to_date)
            },

            credentials: build_credentials
          },

          id: generate_request_id,
          jsonrpc: "2.0"
        }

        response = http_post(@api_url, payload)

        handle_geotab_response(response, "Trip")
      end

      protected

      # Sobrescribir para limpiar estado de Geotab
      def clear_authentication_state
        @session_id = nil
        @database = nil
        @server_path = nil
        @api_url = API_BASE_URL
        Rails.cache.delete(cache_key)

        Rails.logger.info("✓ Estado de autenticación limpiado")
      end

      private


      # Construir objeto credentials para requests
      # Geotab requiere database + sessionId en cada request
      def build_credentials
        {
          database: @database,
          userName: @user_name,
          sessionId: @session_id
        }
      end

      # Clave única para el cache de esta configuración
      def cache_key
        "geotab_session_#{@config.id}"
      end

      # Guardar sesión en cache
      def cache_session
        session_data = {
          session_id: @session_id,
          database: @database,
          server_path: @server_path
        }

        Rails.cache.write(
          cache_key,
          session_data,
          expires_in: SESSION_TTL
        )

        Rails.logger.debug("✓ Sesión cacheada (TTL: #{SESSION_TTL / 60} min)")
      end

      # Cargar sesión desde cache
      # @return [Boolean] true si se cargó exitosamente
      def load_from_cache
        cached = Rails.cache.read(cache_key)
        # Validamos que sea un Hash, si es un Array u otra cosa, lo ignoramos
        return false unless cached.is_a?(Hash)

        # Convertimos a HashWithIndifferentAccess para evitar líos de Symbol vs String
        cached = cached.with_indifferent_access

        @session_id = cached[:session_id]
        @database = cached[:database]
        @server_path = cached[:server_path]
        @api_url = API_BASE_URL

        Rails.logger.debug("✓ Sesión cargada desde cache")
        true
      end

      # Procesar respuesta de Geotab
      # Geotab usa JSON-RPC, puede retornar:
      # - { "result": [...] } → éxito
      # - { "error": { "message": "..." } } → error
      def handle_geotab_response(response, entity_type)
        # Caso 1: Error de Geotab
        if response["error"]
          error_msg = response["error"]["message"]

          # Si es error de credenciales inválidas, limpiar cache
          if error_msg.include?("Invalid credentials") ||
             error_msg.include?("session")

            Rails.logger.warn("⚠ Sesión inválida, limpiando cache...")
            clear_authentication_state

            # Re-lanzar para que el caller intente de nuevo
            raise AuthenticationError, "Sesión expirada"
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
        # Asegurar que sea Time
        date = Time.zone.parse(date.to_s) unless date.is_a?(Time)

        # Convertir a UTC y formatear con milisegundos
        date.utc.iso8601(3)
      end

      # Generar ID único para cada request
      # Útil para debugging y correlacionar logs
      def generate_request_id
        SecureRandom.uuid
      end
    end
  end
end
