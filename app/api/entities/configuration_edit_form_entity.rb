# app/api/entities/configuration_edit_form_entity.rb
module Entities
  class ConfigurationEditFormEntity < Grape::Entity
    expose :id
    expose :tenant_id
    expose :is_active
    expose :activated_at
    expose :created_at
    expose :last_sync_at
    expose :last_sync_status
    expose :provider do |config, _options|
      {
        id: config.integration_provider.id,
        name: config.integration_provider.name,
        slug: config.integration_provider.slug,
        logo_url: config.integration_provider.logo_url
      }
    end
    expose :tenant do |config, _options|
      {
        id: config.tenant.id,
        name: config.tenant.name,
        slug: config.tenant.slug
      }
    end
    expose :authentication_block do |config, _options|
      schema = config.integration_provider.integration_auth_schema

      {
        # Campos requeridos
        fields: schema.auth_fields.map do |field|
          {
            name: field["name"],
            type: field["type"],
            label: field["label"],
            placeholder: field["placeholder"],
            required: field["required"] || false,
            help_text: field["help_text"]
          }
        end,

        # Valores actuales (sin exponer passwords)
        current_values: mask_sensitive_credentials(config.credentials),

        # Estado
        has_credentials: config.credentials.present?,
        credentials_valid: config.last_sync_status != "error",
        last_connection_test: config.last_sync_at
      }
    end
    expose :features_block do |config, _options|
      available = config.integration_provider.integration_features.active.ordered

      {
        available_features: available.map do |feature|
          {
            key: feature.feature_key,
            name: feature.feature_name,
            description: feature.feature_description,
            is_enabled: config.enabled_features.include?(feature.feature_key),
            icon: get_feature_icon(feature.feature_key)
          }
        end,

        enabled_count: config.enabled_features.count,
        total_available: available.count,
        can_disable_all: !config.is_active # Solo se pueden deshabilitar todas si está inactiva
      }
    end
    expose :schedule_block do |config, _options|
      {
        current_schedule: {
          frequency: config.sync_frequency,
          hour: config.sync_hour,
          day_of_week: config.sync_day_of_week,
          day_of_month: config.sync_day_of_month,
          description: config.sync_schedule_description
        },

        options: {
          frequencies: [
            { value: "daily", label: "Diaria" },
            { value: "weekly", label: "Semanal" },
            { value: "monthly", label: "Mensual" }
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
      }
    end
    expose :available_actions do |config, _options|
      {
        can_edit_credentials: true,
        can_edit_features: true,
        can_edit_schedule: true,
        can_activate: !config.is_active && config.can_be_activated?,
        can_deactivate: config.is_active,
        can_test_connection: config.credentials.present?,
        can_sync: config.is_active && config.enabled_features.any?,
        can_delete: !config.is_active
      }
    end

    expose :statistics, if: { include_stats: true } do |config, _options|
      config.sync_statistics
    end

    class << self
      # Enmascarar credenciales sensibles
      def mask_sensitive_credentials(credentials)
        return {} unless credentials.is_a?(Hash)

        masked = {}
        credentials.each do |key, value|
          # Enmascarar passwords y tokens
          if key.to_s.match?(/password|token|secret|key/i)
            masked[key] = "••••••••"
          else
            masked[key] = value
          end
        end
        masked
      end

      def get_feature_icon(feature_key)
        {
          "fuel" => "local_gas_station",
          "battery" => "battery_charging_full",
          "trips" => "route",
          "real_time_location" => "location_on",
          "odometer" => "speed",
          "diagnostics" => "build"
        }[feature_key] || "check_circle"
      end
    end
  end
end
