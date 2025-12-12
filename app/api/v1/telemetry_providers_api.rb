# app/api/v1/telemetry_providers_api.rb
module V1
  class TelemetryProvidersApi < Grape::API
    version "v1", using: :path
    format :json
    prefix :api

    helpers do
      def current_company
        # Implementar según tu sistema de autenticación
        # Por ejemplo: @current_user.company
        Company.find(params[:company_id]) if params[:company_id]
      end

      def generate_example_credentials(provider)
        schema_fields = provider.configuration_schema.fetch("fields", [])
        example = {}

        schema_fields.each do |field|
          example[field["name"]] = field["placeholder"] || field["help_text"] || "your_#{field['name']}"
        end

        example
      end
    end

    resource :telemetry_providers do
      desc "List all available telemetry providers",
           success: Entities::TelemetryProviderEntity,
           is_array: true,
           tags: [ "Telemetry Providers" ]
      params do
        optional :active_only, type: Boolean, default: true, desc: "Filter only active providers"
      end
      get do
        providers = params[:active_only] ? TelemetryProvider.active : TelemetryProvider.all
        present providers, with: Entities::TelemetryProviderEntity
      end

      desc "Get a specific telemetry provider",
           success: Entities::TelemetryProviderEntity,
           tags: [ "Telemetry Providers" ]
      params do
        requires :id, type: Integer, desc: "Provider ID"
      end
      route_param :id do
        get do
          provider = TelemetryProvider.find(params[:id])
          present provider, with: Entities::TelemetryProviderEntity, detailed: true
        end
      end

      desc "Get provider by slug",
           success: Entities::TelemetryProviderEntity,
           tags: [ "Telemetry Providers" ]
      params do
        requires :slug, type: String, desc: "Provider slug (e.g., geotab)"
      end
      get ":slug/details" do
        provider = TelemetryProvider.find_by_slug!(params[:slug])
        present provider, with: Entities::TelemetryProviderEntity, detailed: true
      end

      desc "Get provider configuration schema",
           tags: [ "Telemetry Providers" ]
      params do
        requires :id, type: Integer, desc: "Provider ID"
      end
      route_param :id do
        get :schema do
          provider = TelemetryProvider.find(params[:id])

          {
            provider_id: provider.id,
            provider_name: provider.name,
            provider_slug: provider.slug,
            is_registered: Telemetry::ProviderRegistry.registered?(provider.slug),
            configuration_schema: provider.configuration_schema,
            example_credentials: generate_example_credentials(provider)
          }
        end
      end
    end
  end
end
