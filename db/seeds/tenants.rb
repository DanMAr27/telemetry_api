# db/seeds/tenants.rb
module Seeds
  class Tenants
    def self.run
      create_tenants
      create_configurations
    end

    private

    def self.create_tenants
      puts "\n🏢 Creando Tenants..."

      # Tenant 1 - Acme Corp (Activo con múltiples integraciones)
      acme = Tenant.find_or_create_by!(slug: 'acme-corp') do |t|
        t.name = 'Acme Corporation'
        t.email = 'admin@acme.com'
        t.status = 'active'
        t.settings = {
          timezone: 'Europe/Madrid',
          language: 'es',
          currency: 'EUR'
        }
      end
      puts "  ✓ #{acme.name} creado"

      # Tenant 2 - Tech Solutions (Activo con una integración)
      tech = Tenant.find_or_create_by!(slug: 'tech-solutions') do |t|
        t.name = 'Tech Solutions SL'
        t.email = 'fleet@techsolutions.com'
        t.status = 'active'
        t.settings = {
          timezone: 'Europe/Madrid',
          language: 'es',
          currency: 'EUR'
        }
      end
      puts "  ✓ #{tech.name} creado"

      # Tenant 3 - Global Logistics (Trial)
      global = Tenant.find_or_create_by!(slug: 'global-logistics') do |t|
        t.name = 'Global Logistics Inc'
        t.email = 'admin@globallogistics.com'
        t.status = 'trial'
        t.settings = {
          timezone: 'Europe/Madrid',
          language: 'es',
          currency: 'EUR',
          trial_ends_at: 30.days.from_now
        }
      end
      puts "  ✓ #{global.name} creado"

      # Tenant 4 - Fast Delivery (Suspendido)
      fast = Tenant.find_or_create_by!(slug: 'fast-delivery') do |t|
        t.name = 'Fast Delivery Services'
        t.email = 'contact@fastdelivery.com'
        t.status = 'suspended'
        t.settings = {
          timezone: 'Europe/Madrid',
          language: 'es',
          currency: 'EUR',
          suspended_reason: 'Pago pendiente',
          suspended_at: 5.days.ago
        }
      end
      puts "  ✓ #{fast.name} creado"

      # Tenant 5 - Demo Company (Para demostraciones)
      demo = Tenant.find_or_create_by!(slug: 'demo-company') do |t|
        t.name = 'Demo Company'
        t.email = 'demo@example.com'
        t.status = 'active'
        t.settings = {
          timezone: 'Europe/Madrid',
          language: 'es',
          currency: 'EUR',
          is_demo: true
        }
      end
      puts "  ✓ #{demo.name} creado"

      puts "✅ #{Tenant.count} Tenants creados\n"
    end

    def self.create_configurations
      puts "\n⚙️  Creando Configuraciones de Integraciones..."

      # Obtener tenants
      acme = Tenant.find_by(slug: 'acme-corp')
      tech = Tenant.find_by(slug: 'tech-solutions')
      global = Tenant.find_by(slug: 'global-logistics')
      demo = Tenant.find_by(slug: 'demo-company')

      # Obtener proveedores
      geotab = IntegrationProvider.find_by(slug: 'geotab')
      verizon = IntegrationProvider.find_by(slug: 'verizon_connect')
      tomtom = IntegrationProvider.find_by(slug: 'tomtom_telematics')

      # ========================================================================
      # ACME CORP - 2 configuraciones activas (Geotab y Verizon)
      # ========================================================================

      # Acme -> Geotab (Activa, sincronización diaria)
      acme_geotab = acme.tenant_integration_configurations.find_or_create_by!(
        integration_provider: geotab
      ) do |config|
        config.credentials = {
          database: 'acme_fleet',
          username: 'acme_api_user',
          password: 'geotab_secret_123'
        }
        config.enabled_features = [ 'real_time_location', 'trips', 'odometer', 'fuel', 'battery', 'diagnostics' ]
        config.sync_frequency = 'daily'
        config.sync_hour = 2
        config.is_active = true
        config.activated_at = 15.days.ago
        config.last_sync_at = 6.hours.ago
        config.last_sync_status = 'success'
        config.sync_config = {
          max_records_per_sync: 5000,
          retry_on_error: true,
          notification_email: 'fleet@acme.com'
        }
        config.metadata = {
          setup_by: 'admin@acme.com',
          notes: 'Configuración principal de telemetría'
        }
      end
      puts "  ✓ #{acme.name} -> Geotab (Activa, diaria a las 02:00)"

      # Acme -> Verizon Connect (Activa, sincronización semanal)
      acme_verizon = acme.tenant_integration_configurations.find_or_create_by!(
        integration_provider: verizon
      ) do |config|
        config.credentials = {
          api_key: 'vz_live_acme_xxxxxxxxxxx',
          account_id: 'ACC-ACME-001'
        }
        config.enabled_features = [ 'real_time_location', 'trips', 'odometer', 'fuel' ]
        config.sync_frequency = 'weekly'
        config.sync_hour = 6
        config.sync_day_of_week = 1 # Lunes
        config.is_active = true
        config.activated_at = 10.days.ago
        config.last_sync_at = 2.days.ago
        config.last_sync_status = 'success'
        config.sync_config = {
          max_records_per_sync: 3000,
          retry_on_error: true
        }
        config.metadata = {
          setup_by: 'admin@acme.com',
          notes: 'Integración secundaria para backup'
        }
      end
      puts "  ✓ #{acme.name} -> Verizon (Activa, semanal lunes 06:00)"

      # ========================================================================
      # TECH SOLUTIONS - 1 configuración activa (Geotab)
      # ========================================================================

      tech_geotab = tech.tenant_integration_configurations.find_or_create_by!(
        integration_provider: geotab
      ) do |config|
        config.credentials = {
          database: 'techsolutions_db',
          username: 'tech_user',
          password: 'tech_pass_456'
        }
        config.enabled_features = [ 'trips', 'odometer', 'fuel' ]
        config.sync_frequency = 'daily'
        config.sync_hour = 3
        config.is_active = true
        config.activated_at = 7.days.ago
        config.last_sync_at = 8.hours.ago
        config.last_sync_status = 'success'
        config.sync_config = {
          max_records_per_sync: 1000
        }
      end
      puts "  ✓ #{tech.name} -> Geotab (Activa, diaria a las 03:00)"

      # ========================================================================
      # GLOBAL LOGISTICS - 1 configuración con error (TomTom)
      # ========================================================================

      global_tomtom = global.tenant_integration_configurations.find_or_create_by!(
        integration_provider: tomtom
      ) do |config|
        config.credentials = {
          account: 'global_account',
          username: 'global_api',
          password: 'wrong_password', # Credenciales incorrectas a propósito
          api_key: 'tt_global_key_xxx'
        }
        config.enabled_features = [ 'real_time_location', 'trips', 'odometer' ]
        config.sync_frequency = 'daily'
        config.sync_hour = 1
        config.is_active = true
        config.activated_at = 5.days.ago
        config.last_sync_at = 12.hours.ago
        config.last_sync_status = 'error'
        config.last_sync_error = 'Authentication failed: Invalid credentials'
        config.sync_config = {}
      end
      puts "  ✓ #{global.name} -> TomTom (Activa CON ERROR, diaria a las 01:00)"

      # ========================================================================
      # DEMO COMPANY - Múltiples configuraciones de ejemplo
      # ========================================================================

      # Demo -> Geotab (Activa, mensual al inicio)
      demo_geotab = demo.tenant_integration_configurations.find_or_create_by!(
        integration_provider: geotab
      ) do |config|
        config.credentials = {
          database: 'demo_database',
          username: 'demo_user',
          password: 'demo_pass'
        }
        config.enabled_features = [ 'real_time_location', 'trips', 'odometer', 'fuel', 'battery' ]
        config.sync_frequency = 'monthly'
        config.sync_hour = 0
        config.sync_day_of_month = 'start'
        config.is_active = true
        config.activated_at = 30.days.ago
        config.last_sync_at = 5.days.ago
        config.last_sync_status = 'success'
        config.sync_config = {
          max_records_per_sync: 10000,
          is_demo: true
        }
        config.metadata = {
          is_demo: true,
          demo_data: true
        }
      end
      puts "  ✓ #{demo.name} -> Geotab (Activa, mensual día 1 a las 00:00)"

      # Demo -> Verizon (Inactiva - para mostrar desactivada)
      demo_verizon = demo.tenant_integration_configurations.find_or_create_by!(
        integration_provider: verizon
      ) do |config|
        config.credentials = {
          api_key: 'vz_demo_key',
          account_id: 'ACC-DEMO-001'
        }
        config.enabled_features = [ 'trips', 'fuel' ]
        config.sync_frequency = 'weekly'
        config.sync_hour = 12
        config.sync_day_of_week = 5 # Viernes
        config.is_active = false
        config.activated_at = 20.days.ago
        config.last_sync_at = 8.days.ago
        config.last_sync_status = 'success'
        config.sync_config = {}
        config.metadata = {
          is_demo: true,
          deactivated_reason: 'Ejemplo de configuración inactiva'
        }
      end
      puts "  ✓ #{demo.name} -> Verizon (INACTIVA, semanal viernes 12:00)"

      # Demo -> TomTom (Activa, mensual al final)
      demo_tomtom = demo.tenant_integration_configurations.find_or_create_by!(
        integration_provider: tomtom
      ) do |config|
        config.credentials = {
          account: 'demo_tomtom',
          username: 'demo_tt_user',
          password: 'demo_tt_pass',
          api_key: 'tt_demo_key'
        }
        config.enabled_features = [ 'real_time_location', 'trips' ]
        config.sync_frequency = 'monthly'
        config.sync_hour = 23
        config.sync_day_of_month = 'end'
        config.is_active = true
        config.activated_at = 10.days.ago
        config.last_sync_at = 1.day.ago
        config.last_sync_status = 'success'
        config.sync_config = {
          is_demo: true
        }
        config.metadata = {
          is_demo: true
        }
      end
      puts "  ✓ #{demo.name} -> TomTom (Activa, mensual último día a las 23:00)"

      puts "\n✅ #{TenantIntegrationConfiguration.count} Configuraciones creadas"
      puts "   - Activas: #{TenantIntegrationConfiguration.active.count}"
      puts "   - Inactivas: #{TenantIntegrationConfiguration.inactive.count}"
      puts "   - Con errores: #{TenantIntegrationConfiguration.with_errors.count}\n"
    end
  end
end
