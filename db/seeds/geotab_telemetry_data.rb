# db/seeds/geotab_telemetry_data.rb
# Datos de prueba para simular integración Geotab con telemetría
# Ejecutar con: rails runner db/seeds/geotab_telemetry_data.rb

puts "Creating Geotab telemetry test data..."

tenant = Tenant.first
geotab_config = TenantIntegrationConfiguration.joins(:integration_provider)
  .where(integration_providers: { slug: 'geotab' })
  .where(tenant: tenant)
  .first

if tenant && geotab_config
  # Crear sync execution de Geotab
  sync_execution = IntegrationSyncExecution.create!(
    tenant_integration_configuration: geotab_config,
    feature_key: 'fuel',  # Feature válida de Geotab para repostajes
    trigger_type: 'scheduled',
    status: 'completed',
    started_at: 1.hour.ago,
    finished_at: 30.minutes.ago,
    duration_seconds: 1800,
    records_fetched: 15,
    records_processed: 15,
    records_failed: 0,
    records_skipped: 0,
    duplicate_records: 0
  )

  # Obtener vehículos del tenant
  vehicles = Vehicle.where(tenant: tenant).limit(3)

  if vehicles.any?
    base_date = 3.days.ago

    vehicles.each_with_index do |vehicle, idx|
      # Crear 5 repostajes por vehículo
      5.times do |i|
        refueling_date = base_date + (idx * 12).hours + (i * 6).hours
        quantity = rand(30.0..60.0).round(2)

        # Crear raw data
        raw_data = IntegrationRawData.create!(
          integration_sync_execution: sync_execution,
          tenant_integration_configuration: geotab_config,
          provider_slug: 'geotab',
          feature_key: 'fuel',
          external_id: "geotab_#{vehicle.id}_#{i}",
          raw_data: {
            device_id: "device_#{vehicle.id}",
            timestamp: refueling_date.iso8601,
            fuel_used: quantity,
            odometer: 10000 + (i * 500),
            location: {
              latitude: 40.4168 + rand(-0.1..0.1),
              longitude: -3.7038 + rand(-0.1..0.1)
            }
          },
          processing_status: 'processed',
          normalized_at: 25.minutes.ago
        )

        # Crear VehicleRefueling normalizado
        refueling = VehicleRefueling.create!(
          integration_raw_data: raw_data,
          tenant: tenant,
          vehicle: vehicle,
          refueling_date: refueling_date,
          quantity: quantity,
          odometer: 10000 + (i * 500),
          location_lat: 40.4168 + rand(-0.1..0.1),
          location_lng: -3.7038 + rand(-0.1..0.1),
          source: 'telemetry'
        )

        puts "  ✓ Created refueling for #{vehicle.plate}: #{quantity}L at #{refueling_date}"
      end
    end

    puts "✓ Created #{sync_execution.integration_raw_data.count} raw data records"
    puts "✓ Created #{VehicleRefueling.where(tenant: tenant).count} vehicle refuelings"
  else
    puts "⚠ No vehicles found for tenant"
  end
else
  puts "⚠ Tenant or Geotab config not found"
end
