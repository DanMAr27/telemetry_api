# app/services/integrations/connectors/geotab_connector.rb
require "securerandom"

module Integrations
  module Connectors
    class GeotabConnector < BaseConnector
      # URL base de la API de Geotab
      API_BASE_URL = "https://my.geotab.com/apiv1"

      # ========================================================================
      # AUTENTICACIÓN
      # ========================================================================
      # Geotab usa un sistema de autenticación que retorna un sessionId
      # Este sessionId debe usarse en todas las peticiones posteriores

      def authenticate(credentials)
        # Construir payload según documentación de Geotab
        payload = {
          method: "Authenticate",
          params: {
            userName: credentials["username"] || credentials[:username],
            password: credentials["password"] || credentials[:password],
            database: credentials["database"] || credentials[:database]
          }
        }

        # Realizar petición
        response = http_post(API_BASE_URL, payload)

        # Verificar respuesta
        if response["result"] && response["result"]["credentials"]
          session_id = response["result"]["credentials"]["sessionId"]
          database = response["result"]["credentials"]["database"]
          username = response["result"]["credentials"]["userName"]

          Rails.logger.info("✓ Autenticación Geotab exitosa")

          {
            success: true,
            session_id: session_id,
            database: database,
            username: username,
            path: response["result"]["path"]
          }
        else
          {
            success: false,
            error: "Respuesta de autenticación inválida"
          }
        end

      rescue AuthenticationError => e
        Rails.logger.error("✗ Error de autenticación Geotab: #{e.message}")
        { success: false, error: e.message }
      rescue StandardError => e
        Rails.logger.error("✗ Error inesperado en autenticación: #{e.message}")
        { success: false, error: "Error de conexión: #{e.message}" }
      end

      # ========================================================================
      # OBTENER REPOSTAJES (FillUp)
      # ========================================================================
      # Geotab usa el tipo "FillUp" para representar repostajes de combustible

      def fetch_refuelings(session_data, from_date, to_date)
        # Construir payload según documentación de Geotab
        payload = {
          method: "Get",
          params: {
            typeName: "FillUp",
            search: {
              fromDate: format_date(from_date),
              toDate: format_date(to_date)
            },
            credentials: {
              database: session_data[:database],
              userName: session_data[:username],
              sessionId: session_data[:session_id]
            }
          },
          id: generate_request_id,
          jsonrpc: "2.0"
        }

        Rails.logger.debug("📤 Enviando credentials: database=#{session_data[:database]}, userName=#{session_data[:username]}")

        # Realizar petición
        response = http_post(API_BASE_URL, payload)

        # Extraer resultado
        if response["result"].is_a?(Array)
          Rails.logger.info("✓ Geotab: #{response['result'].count} repostajes obtenidos")
          response["result"]
        else
          Rails.logger.warn("⚠ Geotab: Respuesta sin resultado")
          []
        end

      rescue StandardError => e
        Rails.logger.error("✗ Error al obtener repostajes: #{e.message}")
        raise ApiError, "Error al obtener repostajes: #{e.message}"
      end

      # ========================================================================
      # OBTENER CARGAS ELÉCTRICAS (ChargeEvent)
      # ========================================================================
      # Geotab usa el tipo "ChargeEvent" para eventos de carga de vehículos eléctricos

      def fetch_electric_charges(session_data, from_date, to_date)
        payload = {
          method: "Get",
          params: {
            typeName: "ChargeEvent",
            search: {
              fromDate: format_date(from_date),
              toDate: format_date(to_date)
            },
            credentials: {
              database: session_data[:database],
              userName: session_data[:username],
              sessionId: session_data[:session_id]
            }
          },
          id: generate_request_id,
          jsonrpc: "2.0"
        }

        response = http_post(API_BASE_URL, payload)

        if response["result"].is_a?(Array)
          Rails.logger.info("✓ Geotab: #{response['result'].count} cargas eléctricas obtenidas")
          response["result"]
        else
          Rails.logger.warn("⚠ Geotab: Respuesta sin resultado")
          []
        end

      rescue StandardError => e
        Rails.logger.error("✗ Error al obtener cargas: #{e.message}")
        raise ApiError, "Error al obtener cargas: #{e.message}"
      end

      # ========================================================================
      # OBTENER VIAJES (Trip)
      # ========================================================================
      # Geotab usa el tipo "Trip" para representar viajes/trayectos

      def fetch_trips(session_data, from_date, to_date)
        payload = {
          method: "Get",
          params: {
            typeName: "Trip",
            search: {
              fromDate: format_date(from_date),
              toDate: format_date(to_date)
            },
            credentials: {
              database: session_data[:database],
              userName: session_data[:username],
              sessionId: session_data[:session_id]
            }
          },
          id: generate_request_id,
          jsonrpc: "2.0"
        }

        response = http_post(API_BASE_URL, payload)

        if response["result"].is_a?(Array)
          Rails.logger.info("✓ Geotab: #{response['result'].count} viajes obtenidos")
          response["result"]
        else
          Rails.logger.warn("⚠ Geotab: Respuesta sin resultado")
          []
        end

      rescue StandardError => e
        Rails.logger.error("✗ Error al obtener viajes: #{e.message}")
        raise ApiError, "Error al obtener viajes: #{e.message}"
      end

      # ========================================================================
      # MÉTODOS PARA PRUEBAS DE CONEXIÓN
      # ========================================================================
      # Para el botón "Probar Conexión" en la UI

      def test_connection(credentials)
        result = authenticate(credentials)

        if result[:success]
          {
            success: true,
            message: "Conexión exitosa con Geotab",
            details: {
              database: result[:database],
              session_created: true
            }
          }
        else
          {
            success: false,
            error: result[:error]
          }
        end
      end

      private

      # ========================================================================
      # UTILIDADES
      # ========================================================================

      # Formatear fecha al formato que espera Geotab
      # Formato: "2025-01-01T00:00:00.000Z" (ISO 8601)
      def format_date(date)
        date = Time.zone.parse(date.to_s) unless date.is_a?(Time)
        date.utc.iso8601(3)
      end

      # Generar ID único para request (para trazabilidad)
      def generate_request_id
        SecureRandom.uuid
      end
    end
  end
end
