# app/api/entities/tenant_integration_configuration_entity.rb
module Entities
  class TenantIntegrationConfigurationEntity < Grape::Entity
    expose :id
    expose :tenant_id
    expose :integration_provider_id
    expose :is_active
    expose :activated_at
    expose :sync_frequency
    expose :sync_hour
    expose :sync_day_of_week
    expose :sync_day_of_month
    expose :enabled_features
    expose :sync_config
    expose :last_sync_at
    expose :last_sync_status
    expose :last_sync_error
    expose :metadata
    expose :created_at
    expose :updated_at
    expose :tenant, using: Entities::TenantSummaryEntity, if: { include_tenant: true }
    expose :integration_provider,
           using: Entities::IntegrationProviderEntity,
           if: { include_provider: true }
    expose :provider_info, unless: { include_provider: true } do |config, _options|
      {
        id: config.integration_provider.id,
        name: config.integration_provider.name,
        slug: config.integration_provider.slug,
        logo_url: config.integration_provider.logo_url
      }
    end
    expose :tenant_info, unless: { include_tenant: true } do |config, _options|
      {
        id: config.tenant.id,
        name: config.tenant.name,
        slug: config.tenant.slug,
        status: config.tenant.status
      }
    end
    expose :has_credentials, if: { include_computed: true } do |config, _options|
      config.credentials.present?
    end
    expose :has_error, if: { include_computed: true } do |config, _options|
      config.last_sync_status == "error"
    end
    expose :sync_schedule_description, if: { include_computed: true } do |config, _options|
      case config.sync_frequency
      when "daily"
        "Todos los días a las #{config.sync_hour.to_s.rjust(2, '0')}:00"
      when "weekly"
        day_names = %w[Domingo Lunes Martes Miércoles Jueves Viernes Sábado]
        day_name = day_names[config.sync_day_of_week || 0]
        "Todos los #{day_name} a las #{config.sync_hour.to_s.rjust(2, '0')}:00"
      when "monthly"
        day_desc = config.sync_day_of_month == "start" ? "el primer día del mes" : "el último día del mes"
        "#{day_desc.capitalize} a las #{config.sync_hour.to_s.rjust(2, '0')}:00"
      else
        "No configurada"
      end
    end
    expose :next_sync_at, if: { include_computed: true } do |config, _options|
      next nil unless config.is_active
      next nil unless config.last_sync_at

      base_time = config.last_sync_at

      case config.sync_frequency
      when "daily"
        base_time + 1.day
      when "weekly"
        base_time + 1.week
      when "monthly"
        base_time + 1.month
      else
        nil
      end
    end
    expose :available_features, if: { include_features: true } do |config, _options|
      provider = config.integration_provider
      features = provider.integration_features.where(is_active: true).order(:display_order)
      features.map do |feature|
        {
          feature_key: feature.feature_key,
          feature_name: feature.feature_name,
          feature_description: feature.feature_description,
          is_enabled: config.enabled_features.include?(feature.feature_key)
        }
      end
    end
    expose :required_credentials, if: { include_auth_info: true } do |config, _options|
      schema = config.integration_provider.integration_auth_schema
      next [] unless schema
      schema.auth_fields.map do |field|
        {
          name: field["name"],
          label: field["label"],
          type: field["type"],
          required: field["required"],
          placeholder: field["placeholder"],
          help_text: field["help_text"]
        }
      end
    end
    expose :configured_credentials, if: { include_auth_info: true } do |config, _options|
      next [] unless config.credentials.present?
      schema = config.integration_provider.integration_auth_schema
      next [] unless schema
      schema.auth_fields.map do |field|
        field_name = field["name"]
        field_type = field["type"]
        value = config.credentials[field_name] || config.credentials[field_name.to_sym]
        is_sensitive = field_type == "password" ||
                      field_name.match?(/password|token|secret|key|api_key/i)
        display_value = if is_sensitive && value.present?
          if value.length > 12
            "#{value[0..3]}#{'*' * (value.length - 8)}#{value[-4..]}"
          elsif value.length > 4
            "#{value[0..1]}#{'*' * (value.length - 4)}#{value[-2..]}"
          else
            "*" * value.length
          end
        else
          value
        end
        {
          name: field_name,
          label: field["label"],
          type: field_type,
          value: display_value,
          is_configured: value.present?,
          is_sensitive: is_sensitive
        }
      end
    end
    expose :credentials do |config, _options|
      config.credentials
    end
    expose :status_badge do |config, _options|
      if config.is_active
        config.last_sync_status == "error" ? "active_with_errors" : "active"
      else
        "inactive"
      end
    end
  end
end
