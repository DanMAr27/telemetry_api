# app/api/v1/telemetry_credentials_api.rb
module V1
  class TelemetryCredentialsApi < Grape::API
    version "v1", using: :path
    format :json
    prefix :api

    helpers do
      def current_company
        Company.find(params[:company_id]) if params[:company_id]
      end

      def authorize_company!
        error!("Company not found", 404) unless current_company
      end
    end

    resource :companies do
      route_param :company_id do
        resource :telemetry_credentials do
          desc "List company telemetry credentials",
               success: Entities::TelemetryCredentialEntity,
               is_array: true,
               tags: [ "Telemetry Credentials" ]
          params do
            optional :provider_slug, type: String, desc: "Filter by provider"
            optional :active_only, type: Boolean, default: false
            optional :include_config_schema, type: Boolean, default: false, desc: "Include configuration schema"
          end
          get do
            authorize_company!

            credentials = current_company.telemetry_credentials
            credentials = credentials.for_provider(params[:provider_slug]) if params[:provider_slug]
            credentials = credentials.active if params[:active_only]

            present credentials, with: Entities::TelemetryCredentialEntity,
                    include_provider: true,
                    include_stats: true,
                    include_config_schema: params[:include_config_schema]
          end

          desc "Create telemetry credentials",
               success: Entities::TelemetryCredentialEntity,
               tags: [ "Telemetry Credentials" ]
          params do
            requires :telemetry_provider_id, type: Integer, desc: "Provider ID"
            requires :credentials, type: Hash, desc: "Provider credentials (dynamic based on provider schema)" do
              # Los campos son dinámicos según el proveedor
              # El frontend debe obtenerlos primero del endpoint GET /telemetry_providers/:id
            end
          end
          post do
            authorize_company!

            provider = TelemetryProvider.find(params[:telemetry_provider_id])

            # Verificar que no exista ya una credencial para este proveedor
            existing = current_company.telemetry_credentials.find_by(telemetry_provider_id: provider.id)
            error!("Credentials already exist for this provider", 422) if existing

            # Validar credenciales según schema del proveedor
            validator = Telemetry::CredentialValidator.new(provider, params[:credentials])
            unless validator.valid?
              error!({ errors: validator.errors }, 422)
            end

            credential = TelemetryCredential.new(
              company: current_company,
              telemetry_provider: provider,
              credentials: params[:credentials].to_json,
              is_active: true
            )

            if credential.save
              present credential, with: Entities::TelemetryCredentialEntity, include_provider: true
            else
              error!(credential.errors.full_messages, 422)
            end
          end

          desc "Update telemetry credentials",
               success: Entities::TelemetryCredentialEntity,
               tags: [ "Telemetry Credentials" ]
          params do
            requires :id, type: Integer, desc: "Credential ID"
            optional :credentials, type: Hash, desc: "Updated credentials"
            optional :is_active, type: Boolean, desc: "Active status"
          end
          route_param :id do
            put do
              authorize_company!

              credential = current_company.telemetry_credentials.find(params[:id])

              update_params = {}
              update_params[:credentials] = params[:credentials].to_json if params[:credentials]
              update_params[:is_active] = params[:is_active] if params.key?(:is_active)

              if credential.update(update_params)
                present credential, with: Entities::TelemetryCredentialEntity, include_provider: true
              else
                error!(credential.errors.full_messages, 422)
              end
            end

            desc "Delete telemetry credentials",
                 tags: [ "Telemetry Credentials" ]
            delete do
              authorize_company!

              credential = current_company.telemetry_credentials.find(params[:id])
              credential.destroy

              { success: true, message: "Credentials deleted successfully" }
            end

            desc "Test telemetry credentials connection",
                 tags: [ "Telemetry Credentials" ]
            post :test do
              authorize_company!

              credential = current_company.telemetry_credentials.find(params[:id])
              provider_slug = credential.provider_name

              # Verificar que el proveedor esté registrado
              unless Telemetry::ProviderRegistry.registered?(provider_slug)
                error!("Provider '#{provider_slug}' not implemented yet", 501)
              end

              # Usar el registry para obtener el connector correcto
              connector = Telemetry::ProviderRegistry.build_connector(
                provider_slug,
                credential.credentials_hash
              )

              # Cada connector debe implementar authenticate!
              session_id = connector.authenticate!

              {
                success: true,
                message: "Connection successful",
                provider: provider_slug,
                session_id: session_id
              }

            rescue Telemetry::ProviderRegistry::UnknownProviderError => e
              { success: false, message: e.message }
            rescue => e
              # Capturar errores específicos del conector
              error_class = e.class.name.split("::").last
              { success: false, message: "#{error_class}: #{e.message}" }
            end
          end
        end
      end
    end
  end
end
