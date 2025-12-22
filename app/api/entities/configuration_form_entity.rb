# app/api/entities/configuration_form_entity.rb
module Entities
  class ConfigurationFormEntity < Grape::Entity
    expose :provider_info do |provider, _options|
      {
        id: provider.id,
        name: provider.name,
        slug: provider.slug,
        description: provider.description,
        logo_url: provider.logo_url,
        website_url: provider.website_url,
        is_premium: provider.is_premium
      }
    end
    expose :authentication_fields do |provider, _options|
      schema = provider.integration_auth_schema
      next [] unless schema&.is_active

      schema.auth_fields.map do |field|
        {
          name: field["name"],
          type: field["type"], # "text", "password", "url", "select"
          label: field["label"],
          placeholder: field["placeholder"],
          required: field["required"] || false,
          options: field["options"] || [], # Para campos tipo "select"
          help_text: field["help_text"] # Texto de ayuda adicional
        }
      end
    end
    expose :credentials_example do |provider, _options|
      schema = provider.integration_auth_schema
      schema&.example_credentials || {}
    end
    expose :available_features do |provider, _options|
      provider.integration_features.active.ordered.map do |feature|
        {
          key: feature.feature_key,
          name: feature.feature_name,
          description: feature.feature_description,
          enabled_by_default: false
        }
      end
    end
    expose :sync_schedule_options do |_provider, _options|
      {
        frequencies: [
          { value: "daily", label: "Diaria", description: "Se ejecuta todos los días" },
          { value: "weekly", label: "Semanal", description: "Se ejecuta una vez por semana" },
          { value: "monthly", label: "Mensual", description: "Se ejecuta una vez al mes" }
        ],
        hours: (0..23).map { |h| { value: h, label: "#{h.to_s.rjust(2, '0')}:00" } },
        days_of_week: [
          { value: 0, label: "Domingo" },
          { value: 1, label: "Lunes" },
          { value: 2, label: "Martes" },
          { value: 3, label: "Miércoles" },
          { value: 4, label: "Jueves" },
          { value: 5, label: "Viernes" },
          { value: 6, label: "Sábado" }
        ],
        days_of_month: [
          { value: "start", label: "Primer día del mes" },
          { value: "end", label: "Último día del mes" }
        ]
      }
    end
  end
end
