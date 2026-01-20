# app/api/v1/entities/tenant_integration_configuration_selector_entity.rb
module Entities
  class TenantIntegrationConfigurationSelectorEntity < Grape::Entity
    expose :id, documentation: { type: "Integer", desc: "ID de la configuración" }

    expose :label, documentation: { type: "String", desc: "Etiqueta para mostrar en el selector" } do |config|
      "#{config.integration_provider.name} - #{config.tenant.name}"
    end
  end
end
