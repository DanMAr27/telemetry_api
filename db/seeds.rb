# db/seeds.rb
# Seeds para el sistema de telemetría
# Este archivo elimina y recarga todos los datos de prueba

puts "🧹 Limpiando datos existentes..."

# Orden de eliminación (de dependientes a independientes)
begin
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE telemetry_normalization_errors CASCADE") if ActiveRecord::Base.connection.table_exists?('telemetry_normalization_errors')
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE telemetry_sync_logs CASCADE") if ActiveRecord::Base.connection.table_exists?('telemetry_sync_logs')
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE electric_charges CASCADE") if ActiveRecord::Base.connection.table_exists?('electric_charges')
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE refuels CASCADE") if ActiveRecord::Base.connection.table_exists?('refuels')
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE vehicle_telemetry_configs CASCADE") if ActiveRecord::Base.connection.table_exists?('vehicle_telemetry_configs')
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE vehicles CASCADE") if ActiveRecord::Base.connection.table_exists?('vehicles')
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE telemetry_credentials CASCADE") if ActiveRecord::Base.connection.table_exists?('telemetry_credentials')
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE telemetry_providers CASCADE") if ActiveRecord::Base.connection.table_exists?('telemetry_providers')
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE companies CASCADE") if ActiveRecord::Base.connection.table_exists?('companies')

  # Reset sequences
  ActiveRecord::Base.connection.reset_pk_sequence!('telemetry_normalization_errors') if ActiveRecord::Base.connection.table_exists?('telemetry_normalization_errors')
  ActiveRecord::Base.connection.reset_pk_sequence!('telemetry_sync_logs') if ActiveRecord::Base.connection.table_exists?('telemetry_sync_logs')
  ActiveRecord::Base.connection.reset_pk_sequence!('electric_charges') if ActiveRecord::Base.connection.table_exists?('electric_charges')
  ActiveRecord::Base.connection.reset_pk_sequence!('refuels') if ActiveRecord::Base.connection.table_exists?('refuels')
  ActiveRecord::Base.connection.reset_pk_sequence!('vehicle_telemetry_configs') if ActiveRecord::Base.connection.table_exists?('vehicle_telemetry_configs')
  ActiveRecord::Base.connection.reset_pk_sequence!('vehicles') if ActiveRecord::Base.connection.table_exists?('vehicles')
  ActiveRecord::Base.connection.reset_pk_sequence!('telemetry_credentials') if ActiveRecord::Base.connection.table_exists?('telemetry_credentials')
  ActiveRecord::Base.connection.reset_pk_sequence!('telemetry_providers') if ActiveRecord::Base.connection.table_exists?('telemetry_providers')
  ActiveRecord::Base.connection.reset_pk_sequence!('companies') if ActiveRecord::Base.connection.table_exists?('companies')

  puts "✅ Datos eliminados correctamente"
rescue => e
  puts "⚠️  Error durante la limpieza: #{e.message}"
  puts "Continuando con la creación de datos..."
end

puts ""

# ============================================================================
# PROVEEDORES DE TELEMETRÍA
# ============================================================================
puts "📦 Creando proveedores de telemetría..."

geotab = TelemetryProvider.create!(
  name: "Geotab",
  slug: "geotab",
  api_base_url: "https://my.geotab.com/apiv1",
  is_active: true,
  description: "Geotab is a global leader in IoT and connected transportation solutions",
  configuration_schema: {
    required_fields: [ "userName", "password", "database" ],
    optional_fields: [],
    auth_type: "credentials"
  }
)

webfleet = TelemetryProvider.create!(
  name: "Webfleet (TomTom)",
  slug: "webfleet",
  api_base_url: "https://csv.telematics.tomtom.com/extern",
  is_active: true,
  description: "Webfleet Solutions by Bridgestone - Fleet management platform",
  configuration_schema: {
    required_fields: [ "account", "username", "password", "apikey" ],
    optional_fields: [],
    auth_type: "api_key"
  }
)

teltonika = TelemetryProvider.create!(
  name: "Teltonika",
  slug: "teltonika",
  api_base_url: "https://mapon.com/api/v1",
  is_active: false,
  description: "Teltonika Telematics - GPS tracking and fleet management",
  configuration_schema: {
    required_fields: [ "api_key" ],
    optional_fields: [],
    auth_type: "api_key"
  }
)

puts "  ✓ Creados 3 proveedores"

# ============================================================================
# EMPRESAS
# ============================================================================
puts "🏢 Creando empresas..."

company1 = Company.create!(
  name: "Transportes El Rápido S.L.",
  tax_id: "B12345678",
  email: "info@elrapido.com",
  phone: "+34 900 123 456",
  address: "Calle Principal, 123",
  city: "Barcelona",
  state: "Cataluña",
  postal_code: "08001",
  country: "España",
  is_active: true
)

company2 = Company.create!(
  name: "Logística Verde S.A.",
  tax_id: "A87654321",
  email: "contacto@logisticaverde.com",
  phone: "+34 900 654 321",
  address: "Avenida Sostenible, 45",
  city: "Madrid",
  state: "Madrid",
  postal_code: "28001",
  country: "España",
  is_active: true
)

company3 = Company.create!(
  name: "Distribuciones del Norte",
  tax_id: "B99887766",
  email: "admin@delnorte.com",
  phone: "+34 900 789 012",
  address: "Plaza Mayor, 7",
  city: "Bilbao",
  state: "País Vasco",
  postal_code: "48001",
  country: "España",
  is_active: false
)

puts "  ✓ Creadas 3 empresas"

# ============================================================================
# CREDENCIALES DE TELEMETRÍA
# ============================================================================
puts "🔐 Creando credenciales de telemetría..."

credential1 = TelemetryCredential.create!(
  company_id: company1.id,
  telemetry_provider_id: geotab.id,
  credentials: {
    userName: "user@elrapido.com",
    password: "SecurePass123!",
    database: "elrapido_db"
  }.to_json,
  is_active: true,
  last_sync_at: 2.hours.ago,
  last_successful_sync_at: 2.hours.ago
)

credential2 = TelemetryCredential.create!(
  company_id: company1.id,
  telemetry_provider_id: webfleet.id,
  credentials: {
    account: "elrapido",
    username: "api_user",
    password: "ApiPass456!",
    apikey: "1234567890abcdef"
  }.to_json,
  is_active: true,
  last_sync_at: 1.day.ago,
  last_successful_sync_at: 1.day.ago
)

credential3 = TelemetryCredential.create!(
  company_id: company2.id,
  telemetry_provider_id: geotab.id,
  credentials: {
    userName: "admin@logisticaverde.com",
    password: "GreenPass789!",
    database: "logisticaverde_db"
  }.to_json,
  is_active: true,
  last_sync_at: 30.minutes.ago,
  last_successful_sync_at: 30.minutes.ago
)

puts "  ✓ Creadas 3 credenciales"

# ============================================================================
# VEHÍCULOS
# ============================================================================
puts "🚗 Creando vehículos..."

# Vehículos de Transportes El Rápido (combustión y eléctricos)
vehicle1 = Vehicle.create!(
  company_id: company1.id,
  name: "Furgoneta 1",
  license_plate: "1234ABC",
  vin: "VF1RW000123456789",
  brand: "Renault",
  model: "Master",
  year: 2022,
  fuel_type: "combustion",
  tank_capacity_liters: 80.0,
  is_active: true
)

vehicle2 = Vehicle.create!(
  company_id: company1.id,
  name: "Furgoneta 2",
  license_plate: "5678DEF",
  vin: "VF1RW000987654321",
  brand: "Renault",
  model: "Master",
  year: 2022,
  fuel_type: "combustion",
  tank_capacity_liters: 80.0,
  is_active: true
)

vehicle3 = Vehicle.create!(
  company_id: company1.id,
  name: "Camión 1",
  license_plate: "9012GHI",
  vin: "WDB9340071L123456",
  brand: "Mercedes-Benz",
  model: "Actros",
  year: 2021,
  fuel_type: "combustion",
  tank_capacity_liters: 380.0,
  is_active: true
)

vehicle4 = Vehicle.create!(
  company_id: company1.id,
  name: "Eléctrico 1",
  license_plate: "3456JKL",
  vin: "5YJ3E1EA1KF123456",
  brand: "Tesla",
  model: "Model 3",
  year: 2023,
  fuel_type: "electric",
  battery_capacity_kwh: 75.0,
  is_active: true
)

vehicle5 = Vehicle.create!(
  company_id: company1.id,
  name: "Eléctrico 2",
  license_plate: "7890MNO",
  vin: "WVWZZZAUZLW123456",
  brand: "Volkswagen",
  model: "ID.4",
  year: 2023,
  fuel_type: "electric",
  battery_capacity_kwh: 77.0,
  is_active: true
)

vehicle6 = Vehicle.create!(
  company_id: company1.id,
  name: "Híbrido 1",
  license_plate: "2345PQR",
  vin: "JTDKARFP1K3123456",
  brand: "Toyota",
  model: "Prius",
  year: 2023,
  fuel_type: "hybrid",
  tank_capacity_liters: 43.0,
  battery_capacity_kwh: 8.8,
  is_active: true
)

# Vehículos de Logística Verde (solo eléctricos)
vehicle7 = Vehicle.create!(
  company_id: company2.id,
  name: "EV Delivery 1",
  license_plate: "4567STU",
  vin: "5YJ3E1EB3LF234567",
  brand: "Tesla",
  model: "Model Y",
  year: 2024,
  fuel_type: "electric",
  battery_capacity_kwh: 75.0,
  is_active: true
)

vehicle8 = Vehicle.create!(
  company_id: company2.id,
  name: "EV Delivery 2",
  license_plate: "8901VWX",
  vin: "5YJ3E1EB5LF345678",
  brand: "Tesla",
  model: "Model Y",
  year: 2024,
  fuel_type: "electric",
  battery_capacity_kwh: 75.0,
  is_active: true
)

vehicle9 = Vehicle.create!(
  company_id: company2.id,
  name: "EV Van 1",
  license_plate: "1234YZA",
  vin: "WF0EXXGCAE1234567",
  brand: "Ford",
  model: "E-Transit",
  year: 2024,
  fuel_type: "electric",
  battery_capacity_kwh: 68.0,
  is_active: true
)

vehicle10 = Vehicle.create!(
  company_id: company2.id,
  name: "EV Van 2",
  license_plate: "5678BCD",
  vin: "WF0EXXGCAE2345678",
  brand: "Ford",
  model: "E-Transit",
  year: 2024,
  fuel_type: "electric",
  battery_capacity_kwh: 68.0,
  is_active: true
)

# Vehículo inactivo
vehicle11 = Vehicle.create!(
  company_id: company3.id,
  name: "Camión Viejo",
  license_plate: "9876ZYX",
  brand: "Iveco",
  model: "Stralis",
  year: 2015,
  fuel_type: "combustion",
  tank_capacity_liters: 400.0,
  is_active: false
)

combustion_vehicles = [ vehicle1, vehicle2, vehicle3, vehicle6 ]
electric_vehicles = [ vehicle4, vehicle5, vehicle7, vehicle8, vehicle9, vehicle10 ]
all_vehicles = [ vehicle1, vehicle2, vehicle3, vehicle4, vehicle5, vehicle6, vehicle7, vehicle8, vehicle9, vehicle10, vehicle11 ]

puts "  ✓ Creados 11 vehículos"

# ============================================================================
# CONFIGURACIONES DE TELEMETRÍA POR VEHÍCULO
# ============================================================================
puts "⚙️  Configurando telemetría de vehículos..."

# Configurar vehículos de empresa 1 con Geotab
VehicleTelemetryConfig.create!(
  vehicle_id: vehicle1.id,
  telemetry_credential_id: credential1.id,
  external_device_id: "b1A#{rand(100..999)}",
  sync_frequency: "daily",
  data_types: [ "refuels", "odometer" ],
  is_active: true,
  last_sync_at: 2.hours.ago
)

VehicleTelemetryConfig.create!(
  vehicle_id: vehicle2.id,
  telemetry_credential_id: credential1.id,
  external_device_id: "b2A#{rand(100..999)}",
  sync_frequency: "daily",
  data_types: [ "refuels", "odometer" ],
  is_active: true,
  last_sync_at: 3.hours.ago
)

VehicleTelemetryConfig.create!(
  vehicle_id: vehicle3.id,
  telemetry_credential_id: credential1.id,
  external_device_id: "b3A#{rand(100..999)}",
  sync_frequency: "daily",
  data_types: [ "refuels", "odometer" ],
  is_active: true,
  last_sync_at: 1.hour.ago
)

VehicleTelemetryConfig.create!(
  vehicle_id: vehicle4.id,
  telemetry_credential_id: credential1.id,
  external_device_id: "b4A#{rand(100..999)}",
  sync_frequency: "daily",
  data_types: [ "charges", "odometer" ],
  is_active: true,
  last_sync_at: 4.hours.ago
)

# Configurar vehículos de empresa 2 con Geotab (todos eléctricos)
VehicleTelemetryConfig.create!(
  vehicle_id: vehicle7.id,
  telemetry_credential_id: credential3.id,
  external_device_id: "b10B#{rand(100..999)}",
  sync_frequency: "hourly",
  data_types: [ "charges", "odometer" ],
  is_active: true,
  last_sync_at: 30.minutes.ago
)

VehicleTelemetryConfig.create!(
  vehicle_id: vehicle8.id,
  telemetry_credential_id: credential3.id,
  external_device_id: "b11B#{rand(100..999)}",
  sync_frequency: "hourly",
  data_types: [ "charges", "odometer" ],
  is_active: true,
  last_sync_at: 45.minutes.ago
)

VehicleTelemetryConfig.create!(
  vehicle_id: vehicle9.id,
  telemetry_credential_id: credential3.id,
  external_device_id: "b12B#{rand(100..999)}",
  sync_frequency: "hourly",
  data_types: [ "charges", "odometer" ],
  is_active: true,
  last_sync_at: 20.minutes.ago
)

VehicleTelemetryConfig.create!(
  vehicle_id: vehicle10.id,
  telemetry_credential_id: credential3.id,
  external_device_id: "b13B#{rand(100..999)}",
  sync_frequency: "hourly",
  data_types: [ "charges", "odometer" ],
  is_active: true,
  last_sync_at: 50.minutes.ago
)

puts "  ✓ Configuradas 8 conexiones de telemetría"

# ============================================================================
# REPOSTAJES (COMBUSTIÓN)
# ============================================================================
puts "⛽ Creando repostajes..."

refuel_locations = [
  { lat: 41.3851, lng: 2.1734, name: "Barcelona Centro" },
  { lat: 41.4036, lng: 2.1744, name: "Barcelona Norte" },
  { lat: 40.4168, lng: -3.7038, name: "Madrid Centro" },
  { lat: 43.2630, lng: -2.9350, name: "Bilbao" },
  { lat: 39.4699, lng: -0.3763, name: "Valencia" }
]

refuel_count = 0
combustion_vehicles.each do |vehicle|
  # 15-25 repostajes por vehículo en los últimos 3 meses
  num_refuels = rand(15..25)

  num_refuels.times do |i|
    days_ago = rand(1..90)
    base_odometer = 10000 + (90 - days_ago) * rand(150..300)
    location = refuel_locations.sample

    # Algunos repostajes con anomalías (5%)
    has_anomaly = rand(100) < 5
    volume = if has_anomaly
      vehicle.tank_capacity_liters * rand(1.15..1.3) # Excede capacidad
    else
      rand(30.0..(vehicle.tank_capacity_liters * 0.95))
    end

    Refuel.create!(
      vehicle_id: vehicle.id,
      external_id: "geotab_fillup_#{vehicle.id}_#{SecureRandom.hex(8)}",
      provider_name: "geotab",
      refuel_date: days_ago.days.ago + rand(0..23).hours,
      volume_liters: volume.round(2),
      cost: (volume * rand(1.45..1.65)).round(2),
      currency_code: "EUR",
      location_lat: location[:lat] + rand(-0.05..0.05),
      location_lng: location[:lng] + rand(-0.05..0.05),
      odometer_km: base_odometer.round(2),
      tank_capacity_liters: vehicle.tank_capacity_liters,
      distance_since_last_refuel_km: rand(300..600).round(2),
      confidence_level: has_anomaly ? "Low" : [ "High", "Medium" ].sample,
      product_type: vehicle.fuel_type == "hybrid" ? "Gasoline" : [ "Diesel", "Diesel Plus" ].sample,
      raw_data: {
        device_id: "b#{vehicle.id}A",
        timestamp: days_ago.days.ago.iso8601,
        source: "geotab_api"
      }
    )
    refuel_count += 1
  end
end

puts "  ✓ Creados #{refuel_count} repostajes"

# ============================================================================
# CARGAS ELÉCTRICAS
# ============================================================================
puts "🔋 Creando cargas eléctricas..."

charge_locations = [
  { lat: 41.3879, lng: 2.1699, name: "Supercharger Barcelona" },
  { lat: 40.4165, lng: -3.7026, name: "Punto carga Madrid" },
  { lat: 43.2627, lng: -2.9253, name: "Electrolinera Bilbao" },
  { lat: 39.4840, lng: -0.3386, name: "Carga rápida Valencia" }
]

charge_count = 0
electric_vehicles.each do |vehicle|
  # 20-40 cargas por vehículo en los últimos 3 meses
  num_charges = rand(20..40)

  num_charges.times do |i|
    days_ago = rand(1..90)
    base_odometer = 5000 + (90 - days_ago) * rand(50..150)
    location = charge_locations.sample

    # Distribución: 70% AC (lento), 30% DC (rápido)
    charge_type = rand(100) < 70 ? "AC" : "DC"

    if charge_type == "AC"
      # Carga lenta AC: 3-8 horas, 20-60 kWh
      duration = rand(180..480)
      energy = rand(20.0..60.0)
      power = (energy / (duration / 60.0)).round(3)
    else
      # Carga rápida DC: 15-45 minutos, 30-70 kWh
      duration = rand(15..45)
      energy = rand(30.0..70.0)
      power = (energy / (duration / 60.0)).round(3)
    end

    start_soc = rand(10..30).to_f
    end_soc = [ start_soc + rand(40..70), 100.0 ].min

    # Algunas cargas con baja eficiencia (10%)
    has_low_efficiency = rand(100) < 10
    charger_energy = energy / (has_low_efficiency ? rand(0.70..0.78) : rand(0.88..0.95))

    ElectricCharge.create!(
      vehicle_id: vehicle.id,
      external_id: "geotab_charge_#{vehicle.id}_#{SecureRandom.hex(8)}",
      provider_name: "geotab",
      start_time: days_ago.days.ago + rand(0..23).hours,
      duration_minutes: duration,
      energy_consumed_kwh: energy.round(3),
      start_soc_percent: start_soc.round(2),
      end_soc_percent: end_soc.round(2),
      charge_type: charge_type,
      charge_is_estimated: [ true, false ].sample,
      location_lat: location[:lat] + rand(-0.02..0.02),
      location_lng: location[:lng] + rand(-0.02..0.02),
      odometer_km: base_odometer.round(2),
      peak_power_kw: power.round(3),
      measured_charger_energy_in_kwh: charger_energy.round(3),
      measured_battery_energy_in_kwh: energy.round(3),
      raw_data: {
        device_id: "b#{vehicle.id}B",
        timestamp: days_ago.days.ago.iso8601,
        source: "geotab_api"
      }
    )
    charge_count += 1
  end
end

puts "  ✓ Creadas #{charge_count} cargas eléctricas"

# ============================================================================
# LOGS DE SINCRONIZACIÓN
# ============================================================================
puts "📝 Creando logs de sincronización..."

# Logs exitosos recientes
log1 = TelemetrySyncLog.create!(
  telemetry_credential_id: credential1.id,
  vehicle_id: nil,
  sync_type: "refuels",
  status: "success",
  records_processed: 45,
  records_created: 42,
  records_updated: 2,
  records_skipped: 1,
  started_at: 2.hours.ago,
  completed_at: 2.hours.ago + 15.seconds
)

log2 = TelemetrySyncLog.create!(
  telemetry_credential_id: credential1.id,
  vehicle_id: nil,
  sync_type: "charges",
  status: "success",
  records_processed: 60,
  records_created: 58,
  records_updated: 1,
  records_skipped: 1,
  started_at: 2.hours.ago + 1.minute,
  completed_at: 2.hours.ago + 1.minute + 22.seconds
)

log3 = TelemetrySyncLog.create!(
  telemetry_credential_id: credential3.id,
  vehicle_id: nil,
  sync_type: "charges",
  status: "success",
  records_processed: 75,
  records_created: 72,
  records_updated: 2,
  records_skipped: 1,
  started_at: 30.minutes.ago,
  completed_at: 30.minutes.ago + 28.seconds
)

# Log con error parcial
error_log = TelemetrySyncLog.create!(
  telemetry_credential_id: credential1.id,
  vehicle_id: nil,
  sync_type: "refuels",
  status: "partial",
  records_processed: 50,
  records_created: 42,
  records_updated: 3,
  records_skipped: 5,
  error_message: "Some records failed validation",
  started_at: 1.day.ago,
  completed_at: 1.day.ago + 25.seconds
)

# Log con error completo
failed_log = TelemetrySyncLog.create!(
  telemetry_credential_id: credential2.id,
  vehicle_id: vehicle1.id,
  sync_type: "charges",
  status: "error",
  records_processed: 0,
  records_created: 0,
  records_updated: 0,
  records_skipped: 0,
  error_message: "Authentication failed: Invalid credentials",
  error_details: {
    error_code: "AUTH_001",
    provider_message: "Session expired"
  },
  started_at: 3.days.ago,
  completed_at: 3.days.ago + 2.seconds
)

puts "  ✓ Creados 5 logs de sincronización"

# ============================================================================
# ERRORES DE NORMALIZACIÓN
# ============================================================================
puts "⚠️  Creando errores de normalización..."

# Errores asociados al log parcial
TelemetryNormalizationError.create!(
  telemetry_sync_log_id: error_log.id,
  error_type: "validation_error",
  error_message: "Volume exceeds tank capacity by 25%",
  raw_data: {
    id: "geotab_error_1",
    volume: 105.0,
    tankCapacity: 80.0,
    device: { id: "b1A" }
  },
  provider_name: "geotab",
  data_type: "refuel",
  resolved: false
)

TelemetryNormalizationError.create!(
  telemetry_sync_log_id: error_log.id,
  error_type: "mapping_error",
  error_message: "Vehicle not found for device XYZ123",
  raw_data: {
    id: "geotab_error_2",
    device: { id: "XYZ123" },
    dateTime: "2025-01-01T10:00:00Z"
  },
  provider_name: "geotab",
  data_type: "refuel",
  resolved: false
)

TelemetryNormalizationError.create!(
  telemetry_sync_log_id: error_log.id,
  error_type: "data_format_error",
  error_message: "Invalid date format: '2025-13-45T99:99:99Z'",
  raw_data: {
    id: "geotab_error_3",
    dateTime: "2025-13-45T99:99:99Z",
    volume: 45.5
  },
  provider_name: "geotab",
  data_type: "refuel",
  resolved: true,
  resolved_at: 1.day.ago,
  resolution_notes: "Data corrected manually by admin"
)

puts "  ✓ Creados 3 errores de normalización"

# ============================================================================
# RESUMEN
# ============================================================================
puts ""
puts "=" * 70
puts "✅ SEEDS COMPLETADOS"
puts "=" * 70
puts ""
puts "📊 Resumen de datos creados:"
puts "  • Proveedores de telemetría: 3"
puts "  • Empresas: 3"
puts "  • Credenciales: 3"
puts "  • Vehículos totales: 11"
puts "    - Combustión: 3"
puts "    - Eléctricos: 6"
puts "    - Híbridos: 1"
puts "    - Inactivos: 1"
puts "  • Configuraciones de telemetría: 8"
puts "  • Repostajes: #{refuel_count}"
puts "  • Cargas eléctricas: #{charge_count}"
puts "  • Logs de sincronización: 5"
puts "  • Errores de normalización: 3"
puts ""
puts "🔐 Credenciales de prueba (empresa 1):"
puts "  Provider: Geotab"
puts "  Username: user@elrapido.com"
puts "  Password: SecurePass123!"
puts "  Database: elrapido_db"
puts ""
puts "🏢 Empresas creadas:"
puts "  1. Transportes El Rápido S.L. (ID: #{company1.id})"
puts "  2. Logística Verde S.A. (ID: #{company2.id})"
puts "  3. Distribuciones del Norte (ID: #{company3.id})"
puts ""
puts "🚀 Para ejecutar los seeds:"
puts "  rails db"
