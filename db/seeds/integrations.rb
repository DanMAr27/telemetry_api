# db/seeds/integrations.rb
module Seeds
  class Integrations
    def self.run
      create_categories
      create_providers
      create_auth_schemas
      create_features
    end

    private

    def self.create_categories
      telemetry = IntegrationCategory.find_or_create_by!(slug: 'telemetry') do |c|
        c.name = 'Telemetría'
        c.description = 'Proveedores de telemetría para seguimiento de flotas'
        c.icon = 'truck'
        c.display_order = 1
        c.is_active = true
      end

      puts "✓ Categoría 'Telemetría' creada"
    end

    def self.create_providers
      category = IntegrationCategory.find_by!(slug: 'telemetry')

      # Geotab
      geotab = IntegrationProvider.find_or_create_by!(slug: 'geotab') do |p|
        p.integration_category = category
        p.name = 'Geotab'
        p.api_base_url = 'https://my.geotab.com/apiv1'
        p.description = 'Plataforma líder en telemetría con cobertura global'
        p.logo_url = 'https://ejemplo.com/logos/geotab.png'
        p.website_url = 'https://www.geotab.com'
        p.status = 'active'
        p.is_premium = false
        p.display_order = 1
        p.is_active = true
      end

      # Verizon Connect
      verizon = IntegrationProvider.find_or_create_by!(slug: 'verizon_connect') do |p|
        p.integration_category = category
        p.name = 'Verizon Connect'
        p.api_base_url = 'https://api.verizonconnect.com/v1'
        p.description = 'Solución integral de gestión de flotas'
        p.logo_url = 'https://ejemplo.com/logos/verizon.png'
        p.website_url = 'https://www.verizonconnect.com'
        p.status = 'active'
        p.is_premium = true
        p.display_order = 2
        p.is_active = true
      end

      # TomTom Telematics
      tomtom = IntegrationProvider.find_or_create_by!(slug: 'tomtom_telematics') do |p|
        p.integration_category = category
        p.name = 'TomTom Telematics'
        p.api_base_url = 'https://api.webfleet.com/v3'
        p.description = 'Telemetría profesional con análisis avanzado'
        p.logo_url = 'https://ejemplo.com/logos/tomtom.png'
        p.website_url = 'https://www.tomtom.com/telematics'
        p.status = 'beta'
        p.is_premium = false
        p.display_order = 3
        p.is_active = true
      end

      puts "✓ Proveedores creados: Geotab, Verizon Connect, TomTom"
    end

    def self.create_auth_schemas
      # Geotab - OAuth2 + Database
      geotab = IntegrationProvider.find_by!(slug: 'geotab')
      geotab.create_integration_auth_schema!(
        auth_fields: [
          {
            name: 'database',
            type: 'text',
            label: 'Base de Datos',
            placeholder: 'Ej: my_company',
            required: true
          },
          {
            name: 'username',
            type: 'text',
            label: 'Usuario',
            placeholder: 'usuario@ejemplo.com',
            required: true
          },
          {
            name: 'password',
            type: 'password',
            label: 'Contraseña',
            required: true
          }
        ],
        example_credentials: {
          database: 'demo_company',
          username: 'admin@company.com',
          password: '********'
        },
        is_active: true
      )

      # Verizon Connect - API Key
      verizon = IntegrationProvider.find_by!(slug: 'verizon_connect')
      verizon.create_integration_auth_schema!(
        auth_fields: [
          {
            name: 'api_key',
            type: 'password',
            label: 'API Key',
            placeholder: 'Ingrese su API Key',
            required: true
          },
          {
            name: 'account_id',
            type: 'text',
            label: 'Account ID',
            placeholder: 'Ej: ACC-12345',
            required: true
          }
        ],
        example_credentials: {
          api_key: 'vz_live_xxxxxxxxxxxx',
          account_id: 'ACC-12345'
        },
        is_active: true
      )

      # TomTom - Username/Password/Account
      tomtom = IntegrationProvider.find_by!(slug: 'tomtom_telematics')
      tomtom.create_integration_auth_schema!(
        auth_fields: [
          {
            name: 'account',
            type: 'text',
            label: 'Cuenta',
            placeholder: 'Nombre de cuenta',
            required: true
          },
          {
            name: 'username',
            type: 'text',
            label: 'Usuario',
            required: true
          },
          {
            name: 'password',
            type: 'password',
            label: 'Contraseña',
            required: true
          },
          {
            name: 'api_key',
            type: 'password',
            label: 'API Key',
            required: true
          }
        ],
        example_credentials: {
          account: 'my_account',
          username: 'api_user',
          password: '********',
          api_key: 'tt_xxxxxxxx'
        },
        is_active: true
      )

      puts "✓ Schemas de autenticación creados"
    end

    def self.create_features
      # Features de Geotab
      geotab = IntegrationProvider.find_by!(slug: 'geotab')
      [
        { key: 'real_time_location', name: 'Ubicación en Tiempo Real', desc: 'GPS en tiempo real', order: 1 },
        { key: 'trips', name: 'Viajes', desc: 'Historial de viajes realizados', order: 2 },
        { key: 'odometer', name: 'Kilometraje', desc: 'Odómetro del vehículo', order: 3 },
        { key: 'fuel', name: 'Combustible', desc: 'Nivel y consumo de combustible', order: 4 },
        { key: 'battery', name: 'Batería', desc: 'Estado de batería (eléctricos)', order: 5 },
        { key: 'diagnostics', name: 'Diagnósticos', desc: 'Alertas y diagnósticos del vehículo', order: 6 }
      ].each do |feature|
        geotab.integration_features.find_or_create_by!(feature_key: feature[:key]) do |f|
          f.feature_name = feature[:name]
          f.feature_description = feature[:desc]
          f.display_order = feature[:order]
          f.is_active = true
        end
      end

      # Features de Verizon Connect
      verizon = IntegrationProvider.find_by!(slug: 'verizon_connect')
      [
        { key: 'real_time_location', name: 'Ubicación GPS', desc: 'Tracking en tiempo real', order: 1 },
        { key: 'trips', name: 'Viajes', desc: 'Registro de viajes', order: 2 },
        { key: 'odometer', name: 'Kilometraje', desc: 'Contador de kilómetros', order: 3 },
        { key: 'fuel', name: 'Repostajes', desc: 'Gestión de combustible', order: 4 }
      ].each do |feature|
        verizon.integration_features.find_or_create_by!(feature_key: feature[:key]) do |f|
          f.feature_name = feature[:name]
          f.feature_description = feature[:desc]
          f.display_order = feature[:order]
          f.is_active = true
        end
      end

      # Features de TomTom
      tomtom = IntegrationProvider.find_by!(slug: 'tomtom_telematics')
      [
        { key: 'real_time_location', name: 'Posición GPS', desc: 'Localización en vivo', order: 1 },
        { key: 'trips', name: 'Rutas', desc: 'Historial de rutas', order: 2 },
        { key: 'odometer', name: 'Odómetro', desc: 'Kilómetros recorridos', order: 3 }
      ].each do |feature|
        tomtom.integration_features.find_or_create_by!(feature_key: feature[:key]) do |f|
          f.feature_name = feature[:name]
          f.feature_description = feature[:desc]
          f.display_order = feature[:order]
          f.is_active = true
        end
      end

      puts "✓ Features creadas para todos los proveedores"
    end
  end
end
