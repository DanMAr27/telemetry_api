# app/services/integrations/authentication/authenticate_service.rb
module Integrations
  module Authentication
    class AuthenticateService
      # Tiempo de vida de la sesión en cache (2 horas)
      SESSION_TTL = 2.hours

      def initialize(config)
        @config = config
        @provider = config.integration_provider
      end

      def call
        # PASO 1: Verificar si hay sesión en cache
        cached_session = get_cached_session
        return ServiceResult.success(data: cached_session) if cached_session

        # PASO 2: No hay cache, autenticar
        authenticate_with_provider
      end

      private

      def get_cached_session
        cache_key = "geotab_session_#{@config.id}"
        cached_data = Rails.cache.read(cache_key)

        if cached_data
          Rails.logger.info("✓ Sesión encontrada en cache")
          cached_data
        else
          nil
        end
      end

      def authenticate_with_provider
        # Obtener el conector apropiado
        connector = Integrations::Factories::ConnectorFactory.build(@provider.slug)

        # Llamar al método authenticate del conector
        result = connector.authenticate(@config.credentials)

        if result[:success]
          session_id = result[:session_id]
          database = result[:database]
          username = result[:username]

          # Cachear la sesión CON las credenciales
          session_data = {
            session_id: session_id,
            database: database,
            username: username
          }

          cache_session(session_data)

          ServiceResult.success(
            data: session_data,
            message: "Autenticación exitosa"
          )
        else
          ServiceResult.failure(
            errors: [ result[:error] || "Error de autenticación desconocido" ]
          )
        end

      rescue StandardError => e
        Rails.logger.error("Error al autenticar: #{e.message}")
        ServiceResult.failure(errors: [ "Error de autenticación: #{e.message}" ])
      end

      def cache_session(session_data)
        cache_key = "geotab_session_#{@config.id}"
        Rails.cache.write(cache_key, session_data, expires_in: SESSION_TTL)
        Rails.logger.info("✓ Sesión cacheada: #{cache_key}")
      end
    end
  end
end
