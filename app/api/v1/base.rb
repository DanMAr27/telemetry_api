# app/api/v1/base.rb
module V1
  class Base < Grape::API
    version "v1", using: :path
    prefix :api
    format :json

    # Helpers globales
    helpers do
      def current_user
        # Implementar según tu sistema de autenticación
        # Por ejemplo: User.find_by(api_token: headers['Authorization'])
        @current_user ||= authenticate_user!
      end

      def authenticate_user!
        # Implementar tu lógica de autenticación
        # error!('Unauthorized', 401) unless authenticated?
      end

      def authenticated?
        # Tu lógica de verificación
        true # Temporal para POC
      end
    end

    # Manejo de errores global
    rescue_from ActiveRecord::RecordNotFound do |e|
      error!({ error: "Not Found", message: e.message }, 404)
    end

    rescue_from ActiveRecord::RecordInvalid do |e|
      error!({ error: "Validation Failed", message: e.message }, 422)
    end

    rescue_from Grape::Exceptions::ValidationErrors do |e|
      error!({ error: "Validation Errors", errors: e.errors }, 400)
    end


    mount V1::MarketplaceApi
    mount V1::TenantIntegrationConfigurationsApi
    mount V1::VehiclesApi
    mount V1::VehicleProviderMappingsApi
    mount V1::SyncExecutionsApi
    mount V1::VehicleRefuelingsApi
    mount V1::VehicleElectricChargesApi

    # Configuración mínima de Swagger
    add_swagger_documentation(
      api_version: "v1",
      mount_path: "/swagger_doc", # endpoint JSON de Swagger
      hide_documentation_path: false,
      info: {
        title: "My Grape API V1",
        description: "Documentación básica de la API"
      },
        base_path: "/",
        host: Rails.env.production? ? "telemetry-api-guxp.onrender.com" : "localhost:3000",
        schemes: Rails.env.production? ? [ "https" ] : [ "http" ]
    )
  end
end
