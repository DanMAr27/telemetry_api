# ==============================================================================
# db/seeds.rb - SEED AJUSTADO A MODELOS EXISTENTES
# ==============================================================================

puts "\n" + "="*80
puts "🌱 INICIANDO SEEDS"
puts "="*80 + "\n"

# ==============================================================================
# LIMPIAR DATOS (solo desarrollo)
# ==============================================================================

if Rails.env.development?
  puts "🗑️  Limpiando datos existentes..."

  VehicleElectricCharge.destroy_all
  VehicleRefueling.destroy_all
  IntegrationRawData.destroy_all
  IntegrationSyncExecution.destroy_all
  VehicleProviderMapping.destroy_all
  Vehicle.destroy_all
  TenantIntegrationConfiguration.destroy_all
  Tenant.destroy_all
  IntegrationFeature.destroy_all
  IntegrationAuthSchema.destroy_all
  IntegrationProvider.destroy_all
  IntegrationCategory.destroy_all

  puts "✅ Datos limpiados\n"
end

# ==============================================================================
# FASE 1: MARKETPLACE
# ==============================================================================

puts "\n📦 FASE 1: Marketplace"
puts "-" * 80

# Categoría
puts "\n📁 Categoría..."
telemetry = IntegrationCategory.create!(
  name: 'Telemetría',
  slug: 'telemetry',
  description: 'Proveedores de telemetría vehicular',
  icon: 'truck',
  display_order: 1,
  is_active: true
)
puts "  ✓ #{telemetry.name}"

# Proveedores
puts "\n🏢 Proveedores..."
geotab = IntegrationProvider.create!(
  integration_category: telemetry,
  name: 'Geotab',
  slug: 'geotab',
  api_base_url: 'https://my.geotab.com/apiv1',
  description: 'Líder mundial en telemetría con soporte para flotas mixtas',
  logo_url: 'https://cdn.example.com/logos/geotab.png',
  website_url: 'https://www.geotab.com',
  status: 'active',
  is_premium: false,
  display_order: 1,
  is_active: true
)
puts "  ✓ Geotab"

verizon = IntegrationProvider.create!(
  integration_category: telemetry,
  name: 'Verizon Connect',
  slug: 'verizon_connect',
  api_base_url: 'https://api.verizonconnect.com/v1',
  description: 'Solución integral de gestión de flotas',
  logo_url: 'https://cdn.example.com/logos/verizon.png',
  website_url: 'https://www.verizonconnect.com',
  status: 'active',
  is_premium: true,
  display_order: 2,
  is_active: true
)
puts "  ✓ Verizon Connect"

# Auth Schemas
puts "\n🔐 Auth Schemas..."
IntegrationAuthSchema.create!(
  integration_provider: geotab,
  auth_fields: [
    { name: 'database', type: 'text', label: 'Base de Datos', required: true },
    { name: 'username', type: 'text', label: 'Usuario', required: true },
    { name: 'password', type: 'password', label: 'Contraseña', required: true }
  ],
  example_credentials: {
    database: 'mi_empresa',
    username: 'usuario@empresa.com',
    password: '••••••••'
  },
  is_active: true
)
puts "  ✓ Schema Geotab"

IntegrationAuthSchema.create!(
  integration_provider: verizon,
  auth_fields: [
    { name: 'api_key', type: 'password', label: 'API Key', required: true },
    { name: 'account_id', type: 'text', label: 'Account ID', required: true }
  ],
  example_credentials: {
    api_key: 'vz_live_xxxxxxxxxxxx',
    account_id: 'ACC-12345'
  },
  is_active: true
)
puts "  ✓ Schema Verizon"

# Features
puts "\n⚡ Features..."
[
  { key: 'fuel', name: 'Repostajes', desc: 'Detección automática de repostajes', order: 1 },
  { key: 'battery', name: 'Cargas Eléctricas', desc: 'Eventos de carga de vehículos eléctricos', order: 2 },
  { key: 'odometer', name: 'Odómetro', desc: 'Lecturas de kilometraje', order: 3 },
  { key: 'trips', name: 'Viajes', desc: 'Historial de viajes', order: 4 },
  { key: 'real_time_location', name: 'GPS', desc: 'Ubicación en tiempo real', order: 5 },
  { key: 'diagnostics', name: 'Diagnósticos', desc: 'Alertas del vehículo', order: 6 }
].each do |f|
  IntegrationFeature.create!(
    integration_provider: geotab,
    feature_key: f[:key],
    feature_name: f[:name],
    feature_description: f[:desc],
    display_order: f[:order],
    is_active: true
  )
end
puts "  ✓ 6 features Geotab"

[
  { key: 'fuel', name: 'Combustible', desc: 'Gestión de repostajes', order: 1 },
  { key: 'trips', name: 'Viajes', desc: 'Registro de rutas', order: 2 },
  { key: 'odometer', name: 'Kilometraje', desc: 'Contador de km', order: 3 },
  { key: 'real_time_location', name: 'GPS', desc: 'Tracking en vivo', order: 4 }
].each do |f|
  IntegrationFeature.create!(
    integration_provider: verizon,
    feature_key: f[:key],
    feature_name: f[:name],
    feature_description: f[:desc],
    display_order: f[:order],
    is_active: true
  )
end
puts "  ✓ 4 features Verizon"

# ==============================================================================
# FASE 2: TENANTS
# ==============================================================================

puts "\n📦 FASE 2: Tenants"
puts "-" * 80

acme = Tenant.create!(
  name: 'Acme Corporation',
  slug: 'acme-corp',
  email: 'admin@acme.com',
  status: 'active',
  settings: { timezone: 'Europe/Madrid', language: 'es' }
)
puts "  ✓ #{acme.name}"

tech = Tenant.create!(
  name: 'Tech Solutions',
  slug: 'tech-solutions',
  email: 'fleet@techsolutions.com',
  status: 'active',
  settings: { timezone: 'Europe/Madrid', language: 'es' }
)
puts "  ✓ #{tech.name}"

demo = Tenant.create!(
  name: 'Demo Company',
  slug: 'demo-company',
  email: 'demo@example.com',
  status: 'active',
  settings: { is_demo: true }
)
puts "  ✓ #{demo.name}"

# ==============================================================================
# FASE 3: CONFIGURACIONES
# ==============================================================================

puts "\n📦 FASE 3: Configuraciones"
puts "-" * 80

acme_geotab = TenantIntegrationConfiguration.create!(
  tenant: acme,
  integration_provider: geotab,
  credentials: {
    database: 'database',
    username: 'user',
    password: 'psw'
  },
  enabled_features: [ 'fuel' ],
  sync_frequency: 'daily',
  sync_hour: 2,
  is_active: true,
  activated_at: 15.days.ago,
  last_sync_at: 6.hours.ago,
  last_sync_status: 'success',
  sync_config: {}
)
puts "  ✓ #{acme.name} → Geotab"

tech_geotab = TenantIntegrationConfiguration.create!(
  tenant: tech,
  integration_provider: geotab,
  credentials: {
    database: 'tech_db',
    username: 'tech_user',
    password: 'tech_pass'
  },
  enabled_features: [ 'fuel', 'odometer' ],
  sync_frequency: 'daily',
  sync_hour: 3,
  is_active: true,
  activated_at: 7.days.ago,
  last_sync_at: 8.hours.ago,
  last_sync_status: 'success',
  sync_config: {}
)
puts "  ✓ #{tech.name} → Geotab"

demo_geotab = TenantIntegrationConfiguration.create!(
  tenant: demo,
  integration_provider: geotab,
  credentials: {
    database: 'demo_db',
    username: 'demo_user',
    password: 'demo_pass'
  },
  enabled_features: [ 'fuel', 'battery', 'odometer' ],
  sync_frequency: 'daily',
  sync_hour: 1,
  is_active: true,
  activated_at: 30.days.ago,
  last_sync_at: 4.hours.ago,
  last_sync_status: 'success',
  sync_config: {}
)
puts "  ✓ #{demo.name} → Geotab"

# ==============================================================================
# FASE 4: VEHÍCULOS
# ==============================================================================

puts "\n📦 FASE 4: Vehículos"
puts "-" * 80

# Acme - 4 vehículos
acme_v1 = Vehicle.create!(
  tenant: acme,
  name: 'Ford Transit',
  license_plate: '1234ABC',
  vin: 'WF0NXXGBVNDA12345',
  brand: 'Ford',
  model: 'Transit',
  year: 2022,
  vehicle_type: 'van',
  fuel_type: 'diesel',
  is_electric: false,
  tank_capacity_liters: 80,
  initial_odometer_km: 15000,
  current_odometer_km: 42350,
  status: 'active'
)
puts "  ✓ #{acme_v1.license_plate} (Diesel)"

acme_v2 = Vehicle.create!(
  tenant: acme,
  name: 'Mercedes Actros',
  license_plate: '5678DEF',
  brand: 'Mercedes',
  model: 'Actros',
  year: 2021,
  vehicle_type: 'truck',
  fuel_type: 'diesel',
  is_electric: false,
  tank_capacity_liters: 400,
  initial_odometer_km: 35000,
  current_odometer_km: 128450,
  status: 'active'
)
puts "  ✓ #{acme_v2.license_plate} (Diesel)"

acme_v3 = Vehicle.create!(
  tenant: acme,
  name: 'Tesla Model 3',
  license_plate: '9012GHI',
  brand: 'Tesla',
  model: 'Model 3',
  year: 2023,
  vehicle_type: 'car',
  fuel_type: 'electric',
  is_electric: true,
  battery_capacity_kwh: 60,
  initial_odometer_km: 5000,
  current_odometer_km: 18750,
  status: 'active'
)
puts "  ✓ #{acme_v3.license_plate} (Eléctrico)"

acme_v4 = Vehicle.create!(
  tenant: acme,
  name: 'Toyota Prius',
  license_plate: '3456JKL',
  brand: 'Toyota',
  model: 'Prius',
  year: 2023,
  vehicle_type: 'car',
  fuel_type: 'hybrid',
  is_electric: false,
  tank_capacity_liters: 43,
  battery_capacity_kwh: 8.8,
  initial_odometer_km: 8000,
  current_odometer_km: 25600,
  status: 'active'
)
puts "  ✓ #{acme_v4.license_plate} (Híbrido)"

# Tech - 2 vehículos
tech_v1 = Vehicle.create!(
  tenant: tech,
  name: 'Renault Master',
  license_plate: '7890MNO',
  brand: 'Renault',
  model: 'Master',
  year: 2020,
  vehicle_type: 'van',
  fuel_type: 'diesel',
  is_electric: false,
  tank_capacity_liters: 70,
  initial_odometer_km: 22000,
  current_odometer_km: 67890,
  status: 'active'
)
puts "  ✓ #{tech_v1.license_plate} (Diesel)"

tech_v2 = Vehicle.create!(
  tenant: tech,
  name: 'Peugeot Boxer',
  license_plate: '2345PQR',
  brand: 'Peugeot',
  model: 'Boxer',
  year: 2021,
  vehicle_type: 'van',
  fuel_type: 'diesel',
  is_electric: false,
  tank_capacity_liters: 90,
  initial_odometer_km: 18000,
  current_odometer_km: 54320,
  status: 'active'
)
puts "  ✓ #{tech_v2.license_plate} (Diesel)"

# Demo - 2 vehículos
demo_v1 = Vehicle.create!(
  tenant: demo,
  name: 'Demo Diesel',
  license_plate: 'DEMO001',
  brand: 'Ford',
  model: 'Transit',
  year: 2023,
  vehicle_type: 'van',
  fuel_type: 'diesel',
  is_electric: false,
  tank_capacity_liters: 80,
  initial_odometer_km: 1000,
  current_odometer_km: 12500,
  status: 'active'
)
puts "  ✓ #{demo_v1.license_plate} (Diesel)"

demo_v2 = Vehicle.create!(
  tenant: demo,
  name: 'Demo Eléctrico',
  license_plate: 'DEMO002',
  brand: 'Nissan',
  model: 'e-NV200',
  year: 2023,
  vehicle_type: 'van',
  fuel_type: 'electric',
  is_electric: true,
  battery_capacity_kwh: 40,
  initial_odometer_km: 500,
  current_odometer_km: 8750,
  status: 'active'
)
puts "  ✓ #{demo_v2.license_plate} (Eléctrico)"

# ==============================================================================
# FASE 5: MAPEOS
# ==============================================================================

puts "\n📦 FASE 5: Mapeos Vehículo-Proveedor"
puts "-" * 80

# Acme
VehicleProviderMapping.create!(
  vehicle: acme_v1,
  tenant_integration_configuration: acme_geotab,
  external_vehicle_id: 'b1',
  external_vehicle_name: 'Ford Transit',
  is_active: true,
  mapped_at: 15.days.ago,
  last_sync_at: 6.hours.ago
)
puts "  ✓ #{acme_v1.license_plate} ↔ b1"

VehicleProviderMapping.create!(
  vehicle: acme_v2,
  tenant_integration_configuration: acme_geotab,
  external_vehicle_id: 'b2',
  external_vehicle_name: 'Mercedes Actros',
  is_active: true,
  mapped_at: 15.days.ago,
  last_sync_at: 6.hours.ago
)
puts "  ✓ #{acme_v2.license_plate} ↔ b2"

VehicleProviderMapping.create!(
  vehicle: acme_v3,
  tenant_integration_configuration: acme_geotab,
  external_vehicle_id: 'b3E',
  external_vehicle_name: 'Tesla Model 3',
  is_active: true,
  mapped_at: 12.months.ago,
  last_sync_at: 6.hours.ago
)
puts "  ✓ #{acme_v3.license_plate} ↔ b3E"

# Tech
VehicleProviderMapping.create!(
  vehicle: tech_v1,
  tenant_integration_configuration: tech_geotab,
  external_vehicle_id: 'b10',
  external_vehicle_name: 'Renault Master',
  is_active: true,
  mapped_at: 7.days.ago,
  last_sync_at: 8.hours.ago
)
puts "  ✓ #{tech_v1.license_plate} ↔ b10"

VehicleProviderMapping.create!(
  vehicle: tech_v2,
  tenant_integration_configuration: tech_geotab,
  external_vehicle_id: 'b11',
  external_vehicle_name: 'Peugeot Boxer',
  is_active: true,
  mapped_at: 7.days.ago,
  last_sync_at: 8.hours.ago
)
puts "  ✓ #{tech_v2.license_plate} ↔ b11"

# Demo
VehicleProviderMapping.create!(
  vehicle: demo_v1,
  tenant_integration_configuration: demo_geotab,
  external_vehicle_id: 'demo_b1',
  external_vehicle_name: 'Demo Diesel',
  is_active: true,
  mapped_at: 30.days.ago,
  last_sync_at: 4.hours.ago
)
puts "  ✓ #{demo_v1.license_plate} ↔ demo_b1"

VehicleProviderMapping.create!(
  vehicle: demo_v2,
  tenant_integration_configuration: demo_geotab,
  external_vehicle_id: 'demo_b2E',
  external_vehicle_name: 'Demo Electric',
  is_active: true,
  mapped_at: 30.days.ago,
  last_sync_at: 4.hours.ago
)
puts "  ✓ #{demo_v2.license_plate} ↔ demo_b2E"

# ==============================================================================
# FASE 6: EJECUCIONES
# ==============================================================================

puts "\n📦 FASE 6: Ejecuciones de Sincronización"
puts "-" * 80

acme_fuel_exec = IntegrationSyncExecution.create!(
  tenant_integration_configuration: acme_geotab,
  feature_key: 'fuel',
  trigger_type: 'scheduled',
  status: 'completed',
  started_at: 6.hours.ago,
  finished_at: 6.hours.ago + 45.seconds,
  duration_seconds: 45,
  records_fetched: 5,
  records_processed: 5,
  records_failed: 0,
  records_skipped: 0,
  metadata: {}
)
puts "  ✓ Acme Fuel (completada)"

acme_battery_exec = IntegrationSyncExecution.create!(
  tenant_integration_configuration: acme_geotab,
  feature_key: 'battery',
  trigger_type: 'scheduled',
  status: 'completed',
  started_at: 6.hours.ago + 1.minute,
  finished_at: 6.hours.ago + 1.minute + 30.seconds,
  duration_seconds: 30,
  records_fetched: 8,
  records_processed: 8,
  records_failed: 0,
  records_skipped: 0,
  metadata: {}
)
puts "  ✓ Acme Battery (completada)"

tech_fuel_exec = IntegrationSyncExecution.create!(
  tenant_integration_configuration: tech_geotab,
  feature_key: 'fuel',
  trigger_type: 'scheduled',
  status: 'completed',
  started_at: 8.hours.ago,
  finished_at: 8.hours.ago + 25.seconds,
  duration_seconds: 25,
  records_fetched: 3,
  records_processed: 3,
  records_failed: 0,
  records_skipped: 0,
  metadata: {}
)
puts "  ✓ Tech Fuel (completada)"

demo_fuel_exec = IntegrationSyncExecution.create!(
  tenant_integration_configuration: demo_geotab,
  feature_key: 'fuel',
  trigger_type: 'manual',
  status: 'completed',
  started_at: 4.hours.ago,
  finished_at: 4.hours.ago + 20.seconds,
  duration_seconds: 20,
  records_fetched: 3,
  records_processed: 3,
  records_failed: 0,
  records_skipped: 0,
  metadata: {}
)
puts "  ✓ Demo Fuel (completada)"

demo_battery_exec = IntegrationSyncExecution.create!(
  tenant_integration_configuration: demo_geotab,
  feature_key: 'battery',
  trigger_type: 'manual',
  status: 'completed',
  started_at: 4.hours.ago + 30.seconds,
  finished_at: 4.hours.ago + 45.seconds,
  duration_seconds: 15,
  records_fetched: 2,
  records_processed: 2,
  records_failed: 0,
  records_skipped: 0,
  metadata: {}
)
puts "  ✓ Demo Battery (completada)"

# ==============================================================================
# FASE 7: DATOS RAW
# ==============================================================================

puts "\n📦 FASE 7: Datos RAW"
puts "-" * 80

# Acme Fuel (5 registros)
acme_fuel_raws = []
5.times do |i|
  days_ago = 25 - (i * 5)
  device_id = i < 3 ? 'b1' : 'b2'

  raw = IntegrationRawData.create!(
    integration_sync_execution: acme_fuel_exec,
    tenant_integration_configuration: acme_geotab,
    provider_slug: 'geotab',
    feature_key: 'fuel',
    external_id: "fillup_acme_#{i+1}",
    raw_data: {
      id: "fillup_acme_#{i+1}",
      device: { id: device_id },
      dateTime: days_ago.days.ago.iso8601,
      volume: (40 + rand(20)).round(2),
      cost: (50 + rand(30)).round(2),
      currencyCode: 'EUR',
      location: { x: 2.1786, y: 41.3874 },
      odometer: 40000 + (i * 1500)
    },
    processing_status: 'normalized',
    normalized_record_type: 'VehicleRefueling'
  )
  acme_fuel_raws << raw
end
puts "  ✓ 5 RAW Fuel Acme"

# Acme Battery (8 registros)
acme_battery_raws = []
8.times do |i|
  days_ago = 28 - (i * 3)

  raw = IntegrationRawData.create!(
    integration_sync_execution: acme_battery_exec,
    tenant_integration_configuration: acme_geotab,
    provider_slug: 'geotab',
    feature_key: 'battery',
    external_id: "charge_acme_#{i+1}",
    raw_data: {
      id: "charge_acme_#{i+1}",
      device: { id: 'b3E' },
      startTime: days_ago.days.ago.change(hour: 22).iso8601,
      duration: "03:#{15+rand(30)}:00",
      energyConsumedKwh: (10 + rand(15)).round(3),
      startStateOfCharge: (20 + rand(30)).round(2),
      endStateOfCharge: (70 + rand(25)).round(2),
      chargeType: rand > 0.7 ? 'DC' : 'AC',
      location: { x: 2.1786, y: 41.3874 }
    },
    processing_status: 'normalized',
    normalized_record_type: 'VehicleElectricCharge'
  )
  acme_battery_raws << raw
end
puts "  ✓ 8 RAW Battery Acme"

# Tech Fuel (3 registros)
tech_fuel_raws = []
3.times do |i|
  days_ago = 22 - (i * 7)
  device_id = i < 2 ? 'b10' : 'b11'

  raw = IntegrationRawData.create!(
    integration_sync_execution: tech_fuel_exec,
    tenant_integration_configuration: tech_geotab,
    provider_slug: 'geotab',
    feature_key: 'fuel',
    external_id: "fillup_tech_#{i+1}",
    raw_data: {
      id: "fillup_tech_#{i+1}",
      device: { id: device_id },
      dateTime: days_ago.days.ago.iso8601,
      volume: (50 + rand(25)).round(2),
      cost: (60 + rand(35)).round(2),
      currencyCode: 'EUR',
      location: { x: 2.1786, y: 41.3874 },
      odometer: 60000 + (i * 2000)
    },
    processing_status: 'normalized',
    normalized_record_type: 'VehicleRefueling'
  )
  tech_fuel_raws << raw
end
puts "  ✓ 3 RAW Fuel Tech"

# Demo Fuel (3 registros)
demo_fuel_raws = []
3.times do |i|
  days_ago = 20 - (i * 7)

  raw = IntegrationRawData.create!(
    integration_sync_execution: demo_fuel_exec,
    tenant_integration_configuration: demo_geotab,
    provider_slug: 'geotab',
    feature_key: 'fuel',
    external_id: "fillup_demo_#{i+1}",
    raw_data: {
      id: "fillup_demo_#{i+1}",
      device: { id: 'demo_b1' },
      dateTime: days_ago.days.ago.iso8601,
      volume: (45 + rand(15)).round(2),
      cost: (55 + rand(25)).round(2),
      currencyCode: 'EUR',
      location: { x: 2.1786, y: 41.3874 },
      odometer: 10000 + (i * 800)
    },
    processing_status: 'normalized',
    normalized_record_type: 'VehicleRefueling'
  )
  demo_fuel_raws << raw
end
puts "  ✓ 3 RAW Fuel Demo"

# Demo Battery (2 registros)
demo_battery_raws = []
2.times do |i|
  days_ago = 15 - (i * 7)

  raw = IntegrationRawData.create!(
    integration_sync_execution: demo_battery_exec,
    tenant_integration_configuration: demo_geotab,
    provider_slug: 'geotab',
    feature_key: 'battery',
    external_id: "charge_demo_#{i+1}",
    raw_data: {
      id: "charge_demo_#{i+1}",
      device: { id: 'demo_b2E' },
      startTime: days_ago.days.ago.change(hour: 20).iso8601,
      duration: "03:15:00",
      energyConsumedKwh: (18 + rand(8)).round(3),
      startStateOfCharge: 25.0,
      endStateOfCharge: 95.0,
      chargeType: 'AC',
      location: { x: 2.1786, y: 41.3874 }
    },
    processing_status: 'normalized',
    normalized_record_type: 'VehicleElectricCharge'
  )
  demo_battery_raws << raw
end
puts "  ✓ 2 RAW Battery Demo"

# ==============================================================================
# FASE 8: REPOSTAJES
# ==============================================================================

puts "\n📦 FASE 8: Repostajes Normalizados"
puts "-" * 80

# Acme
acme_fuel_raws.each do |raw|
  vehicle = raw.raw_data['device']['id'] == 'b1' ? acme_v1 : acme_v2

  refuel = VehicleRefueling.create!(
    tenant: acme,
    vehicle: vehicle,
    integration_raw_data: raw,
    refueling_date: Time.parse(raw.raw_data['dateTime']),
    volume_liters: raw.raw_data['volume'],
    cost: raw.raw_data['cost'],
    currency: raw.raw_data['currencyCode'],
    location_lat: raw.raw_data.dig('location', 'y'),
    location_lng: raw.raw_data.dig('location', 'x'),
    odometer_km: raw.raw_data['odometer'],
    fuel_type: 'Diesel',
    is_estimated: false,
    tank_capacity_liters: vehicle.tank_capacity_liters
  )

  raw.update!(normalized_record_id: refuel.id)
end
puts "  ✓ 5 repostajes Acme"

# Tech
tech_fuel_raws.each do |raw|
  vehicle = raw.raw_data['device']['id'] == 'b10' ? tech_v1 : tech_v2

  refuel = VehicleRefueling.create!(
    tenant: tech,
    vehicle: vehicle,
    integration_raw_data: raw,
    refueling_date: Time.parse(raw.raw_data['dateTime']),
    volume_liters: raw.raw_data['volume'],
    cost: raw.raw_data['cost'],
    currency: raw.raw_data['currencyCode'],
    location_lat: raw.raw_data.dig('location', 'y'),
    location_lng: raw.raw_data.dig('location', 'x'),
    odometer_km: raw.raw_data['odometer'],
    fuel_type: 'Diesel',
    is_estimated: false,
    tank_capacity_liters: vehicle.tank_capacity_liters
  )

  raw.update!(normalized_record_id: refuel.id)
end
puts "  ✓ 3 repostajes Tech"

# Demo
demo_fuel_raws.each do |raw|
  refuel = VehicleRefueling.create!(
    tenant: demo,
    vehicle: demo_v1,
    integration_raw_data: raw,
    refueling_date: Time.parse(raw.raw_data['dateTime']),
    volume_liters: raw.raw_data['volume'],
    cost: raw.raw_data['cost'],
    currency: raw.raw_data['currencyCode'],
    location_lat: raw.raw_data.dig('location', 'y'),
    location_lng: raw.raw_data.dig('location', 'x'),
    odometer_km: raw.raw_data['odometer'],
    fuel_type: 'Diesel',
    is_estimated: false,
    tank_capacity_liters: demo_v1.tank_capacity_liters
  )

  raw.update!(normalized_record_id: refuel.id)
end
puts "  ✓ 3 repostajes Demo"

# ==============================================================================
# FASE 9: CARGAS ELÉCTRICAS
# ==============================================================================

puts "\n📦 FASE 9: Cargas Eléctricas Normalizadas"
puts "-" * 80

# Acme
acme_battery_raws.each do |raw|
  duration_parts = raw.raw_data['duration'].split(':')
  duration_minutes = (duration_parts[0].to_i * 60) + duration_parts[1].to_i

  charge = VehicleElectricCharge.create!(
    tenant: acme,
    vehicle: acme_v3,
    integration_raw_data: raw,
    charge_start_time: Time.parse(raw.raw_data['startTime']),
    duration_minutes: duration_minutes,
    energy_consumed_kwh: raw.raw_data['energyConsumedKwh'],
    start_soc_percent: raw.raw_data['startStateOfCharge'],
    end_soc_percent: raw.raw_data['endStateOfCharge'],
    charge_type: raw.raw_data['chargeType'],
    location_lat: raw.raw_data.dig('location', 'y'),
    location_lng: raw.raw_data.dig('location', 'x'),
    is_estimated: false
  )

  raw.update!(normalized_record_id: charge.id)
end
puts "  ✓ 8 cargas Acme Tesla"

# Demo
demo_battery_raws.each do |raw|
  duration_parts = raw.raw_data['duration'].split(':')
  duration_minutes = (duration_parts[0].to_i * 60) + duration_parts[1].to_i

  charge = VehicleElectricCharge.create!(
    tenant: demo,
    vehicle: demo_v2,
    integration_raw_data: raw,
    charge_start_time: Time.parse(raw.raw_data['startTime']),
    duration_minutes: duration_minutes,
    energy_consumed_kwh: raw.raw_data['energyConsumedKwh'],
    start_soc_percent: raw.raw_data['startStateOfCharge'],
    end_soc_percent: raw.raw_data['endStateOfCharge'],
    charge_type: raw.raw_data['chargeType'],
    location_lat: raw.raw_data.dig('location', 'y'),
    location_lng: raw.raw_data.dig('location', 'x'),
    is_estimated: false
  )

  raw.update!(normalized_record_id: charge.id)
end
puts "  ✓ 2 cargas Demo"

# ==============================================================================
# RESUMEN
# ==============================================================================

puts "\n" + "="*80
puts "✅ SEEDS COMPLETADOS"
puts "="*80

puts "\n📊 RESUMEN:\n"
puts "   Categorías: #{IntegrationCategory.count}"
puts "   Proveedores: #{IntegrationProvider.count}"
puts "   Auth Schemas: #{IntegrationAuthSchema.count}"
puts "   Features: #{IntegrationFeature.count}"
puts "   Tenants: #{Tenant.count}"
puts "   Configuraciones: #{TenantIntegrationConfiguration.count}"
puts "   Vehículos: #{Vehicle.count}"
puts "   Mapeos: #{VehicleProviderMapping.count}"
puts "   Ejecuciones: #{IntegrationSyncExecution.count}"
puts "   Datos RAW: #{IntegrationRawData.count}"
puts "   Repostajes: #{VehicleRefueling.count}"
puts "   Cargas: #{VehicleElectricCharge.count}"

puts "\n💡 Consultas de ejemplo:"
puts "   acme = Tenant.find_by(slug: 'acme-corp')"
puts "   acme.vehicles"
puts "   acme.tenant_integration_configurations"
puts "   acme.vehicles.first.vehicle_refuelings"
puts "   Vehicle.find_by(license_plate: '9012GHI').vehicle_electric_charges"

puts "\n" + "="*80 + "\n"
