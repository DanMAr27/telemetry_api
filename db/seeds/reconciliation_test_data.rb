# db/seeds/reconciliation_test_data.rb
# Seed completo para testing de reconciliación
# Ejecutar con: rails runner db/seeds/reconciliation_test_data.rb

puts "=" * 80
puts "CREATING RECONCILIATION TEST DATA"
puts "=" * 80

# 1. CREAR TENANT Y CONFIGURACIONES
puts "\n1. Creating tenant and configurations..."

tenant = Tenant.find_by(name: 'Test Company') || Tenant.first
if tenant.nil?
  tenant = Tenant.create!(name: 'Test Company', slug: 'test-company')
end
puts "  ✓ Tenant: #{tenant.name} (ID: #{tenant.id})"

# Obtener providers (no cambian)
geotab = IntegrationProvider.find_by(slug: 'geotab')
solred = IntegrationProvider.find_by(slug: 'solred')

# Configuración Geotab
geotab_config = TenantIntegrationConfiguration.find_or_create_by!(
  tenant: tenant,
  integration_provider: geotab
) do |c|
  c.is_active = true
  c.credentials = { database: 'test_db', username: 'test_user', password: 'test_pass' }
  c.enabled_features = [ 'fuel', 'battery', 'trips' ]
end
puts "  ✓ Geotab config: #{geotab_config.id}"

# Configuración Solred
solred_config = TenantIntegrationConfiguration.find_or_create_by!(
  tenant: tenant,
  integration_provider: solred
) do |c|
  c.is_active = true
  c.credentials = { client_code: '0002601' }
  c.enabled_features = [ 'financial_import' ]
end
puts "  ✓ Solred config: #{solred_config.id}"

# 2. CREAR VEHÍCULOS
puts "\n2. Cleaning and Creating vehicles..."

# Limpiar vehículos de prueba previos para asegurar limpieza
plates = [ '3554MWK', '8389LYG', '3560MWK', 'EV001' ]
Vehicle.where(tenant: tenant, license_plate: plates).destroy_all
VehicleRefueling.where(tenant: tenant).destroy_all
VehicleElectricCharge.where(tenant: tenant).destroy_all

# Crear vehículos
vehicles_data = [
  { license_plate: '3554MWK', name: 'Mercedes Sprinter 3554MWK', brand: 'Mercedes', model: 'Sprinter', fuel_type: 'diesel', is_electric: false },
  { license_plate: '8389LYG', name: 'Renault Master 8389LYG', brand: 'Renault', model: 'Master', fuel_type: 'diesel', is_electric: false },
  { license_plate: '3560MWK', name: 'Volkswagen Crafter 3560MWK', brand: 'Volkswagen', model: 'Crafter', fuel_type: 'diesel', is_electric: false },
  { license_plate: 'EV001', name: 'Tesla Model 3 EV001', brand: 'Tesla', model: 'Model 3', fuel_type: 'electric', is_electric: true }
]

vehicles = vehicles_data.map do |vdata|
  Vehicle.create!(
    tenant: tenant,
    license_plate: vdata[:license_plate],
    name: vdata[:name],
    brand: vdata[:brand],
    model: vdata[:model],
    fuel_type: vdata[:fuel_type],
    is_electric: vdata[:is_electric],
    year: 2020,
    status: 'active'
  )
end

vehicles.each { |v| puts "  ✓ Vehicle: #{v.license_plate} (ID: #{v.id})" }

# 3. CREAR SYNC EXECUTION DE GEOTAB (Simulada)
puts "\n3. Creating Geotab sync execution..."
sync_execution = IntegrationSyncExecution.create!(
  tenant_integration_configuration: geotab_config,
  feature_key: 'fuel',
  trigger_type: 'scheduled',
  status: 'completed',
  started_at: 2.hours.ago,
  finished_at: 1.hour.ago,
  duration_seconds: 3600,
  records_fetched: 20,
  records_processed: 20
)
puts "  ✓ Sync execution ID: #{sync_execution.id}"

# 4. CREAR TELEMETRÍA (Refuelings & Electric Charges)
puts "\n4. Creating matching telemetry data..."

base_date = 3.days.ago
count_fuel = 0
count_electric = 0

vehicles.each_with_index do |vehicle, idx|
  5.times do |i|
    # Semilla determinista idéntica a generate_solred_test_file.rb
    srand(idx * 100 + i)

    transaction_date = base_date + (idx * 12).hours + (i * 6).hours
    telemetry_date = transaction_date + rand(-15..15).minutes # Pequeña variación temporal realista

    if vehicle.is_electric
      # Generar carga eléctrica
      quantity = rand(20.0..40.0).round(2) # kWh

      # Raw Data
      raw_data = IntegrationRawData.create!(
        integration_sync_execution: sync_execution,
        tenant_integration_configuration: geotab_config,
        provider_slug: 'geotab',
        feature_key: 'battery',
        external_id: "geotab_charge_#{vehicle.id}_#{i}",
        raw_data: {
          device_id: "geotab_device_#{vehicle.id}",
          timestamp: telemetry_date.iso8601,
          energy_consumed_kwh: quantity,
          battery_level: 80
        },
        processing_status: 'normalized',
        normalized_at: Time.current
      )

      # VehicleElectricCharge
      VehicleElectricCharge.create!(
        integration_raw_data: raw_data,
        tenant: tenant,
        vehicle: vehicle,
        charge_start_time: telemetry_date,
        charge_end_time: telemetry_date + 45.minutes,
        energy_consumed_kwh: quantity,
        location_lat: 41.3851,
        location_lng: 2.1734,
        source: 'telemetry'
      )
      count_electric += 1
    else
      # Generar repostaje combustible
      quantity = rand(30.0..60.0).round(2) # Litros

      # Raw Data
      raw_data = IntegrationRawData.create!(
        integration_sync_execution: sync_execution,
        tenant_integration_configuration: geotab_config,
        provider_slug: 'geotab',
        feature_key: 'fuel',
        external_id: "geotab_fuel_#{vehicle.id}_#{i}",
        raw_data: {
          device_id: "geotab_device_#{vehicle.id}",
          timestamp: telemetry_date.iso8601,
          fuel_used: quantity,
          odometer_km: 50000
        },
        processing_status: 'normalized',
        normalized_at: Time.current
      )

      # VehicleRefueling
      VehicleRefueling.create!(
        integration_raw_data: raw_data,
        tenant: tenant,
        vehicle: vehicle,
        refueling_date: telemetry_date,
        volume_liters: quantity,
        odometer_km: 50000 + (idx * 1000) + (i * 100),
        location_lat: 41.3851 + rand(-0.01..0.01),
        location_lng: 2.1734 + rand(-0.01..0.01),
        source: 'telemetry'
      )
      count_fuel += 1
    end
  end
end

puts "  ✓ Created #{count_fuel} refuelings and #{count_electric} electric charges"


# 7. RESUMEN
puts "\n" + "=" * 80
puts "SUMMARY"
puts "=" * 80
puts "Tenant: #{tenant.name} (ID: #{tenant.id})"
puts "Vehicles: #{Vehicle.where(tenant: tenant).count}"
puts "  - Fuel vehicles: #{vehicles.count}"
puts "  - Electric vehicles: 1"
puts "Vehicle Refuelings: #{VehicleRefueling.where(tenant: tenant).count}"
puts "Electric Charges: #{VehicleElectricCharge.where(tenant: tenant).count}"
puts "Integration Raw Data: #{IntegrationRawData.where(integration_sync_execution: sync_execution).count}"
puts ""
puts "Configurations:"
puts "  - Geotab: #{geotab_config.id}"
puts "  - Solred: #{solred_config.id}"
puts ""
puts "Next steps:"
puts "1. Load product catalog: rails runner db/seeds/product_catalogs.rb"
puts "2. Generate Solred file: rails runner db/seeds/generate_solred_test_file.rb"
puts "3. Upload file via Swagger"
puts "4. Execute reconciliation: POST /api/v1/integration_configurations/#{solred_config.id}/reconcile"
puts "=" * 80
