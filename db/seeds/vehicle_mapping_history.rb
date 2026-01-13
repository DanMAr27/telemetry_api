# db/seeds/vehicle_mapping_history.rb

puts "\n⏳ Generando Datos de Mapeo Histórico (Vehicle Provider Mapping History)..."

# Asegurar que tenemos el tenant principal
tenant = Tenant.find_by(slug: 'acme-corp')
unless tenant
  puts "⚠️  Tenant 'Acme Corp' no encontrado. Saltando seeds de histórico."
  return
end

# Configuración de Geotab
geo_config = tenant.tenant_integration_configurations.joins(:integration_provider).find_by(integration_providers: { slug: 'geotab' })
unless geo_config
  puts "⚠️  Configuración Geotab para Acme no encontrada. Saltando seeds de histórico."
  return
end

# Caso 1: ID Reciclado (Dispositivo movido de Vehículo A a Vehículo B)
# Vehículo A (Antiguo dueño del dispositivo)
vehicle_old = Vehicle.create!(
  tenant: tenant,
  name: "Vehículo Histórico A (Ex-Dispositivo 999)",
  license_plate: "HIST-A01",
  status: "active",
  fuel_type: "diesel"
)

# Vehículo B (Nuevo dueño del dispositivo)
vehicle_new = Vehicle.create!(
  tenant: tenant,
  name: "Vehículo Actual B (Con Dispositivo 999)",
  license_plate: "CURR-B02",
  status: "active",
  fuel_type: "diesel"
)

device_id = "GEO-DEVICE-999"

# Crear mapeo histórico cerrado para Vehículo A (Enero - Feb)
VehicleProviderMapping.create!(
  vehicle: vehicle_old,
  tenant_integration_configuration: geo_config,
  external_vehicle_id: device_id,
  external_vehicle_name: "Dispositivo 999 (Antes en A)",
  is_active: false,
  mapped_at: 3.months.ago,
  valid_from: 3.months.ago,
  valid_until: 1.month.ago
)
puts "  ✓ Mapeo Histórico: #{vehicle_old.license_plate} tuvo #{device_id} (hace 3 meses -> hace 1 mes)"

# Crear mapeo activo actual para Vehículo B (Desde hace 1 mes)
VehicleProviderMapping.create!(
  vehicle: vehicle_new,
  tenant_integration_configuration: geo_config,
  external_vehicle_id: device_id,
  external_vehicle_name: "Dispositivo 999 (Ahora en B)",
  is_active: true,
  mapped_at: 1.month.ago,
  valid_from: 1.month.ago,
  valid_until: nil
)
puts "  ✓ Mapeo Activo: #{vehicle_new.license_plate} tiene #{device_id} (desde hace 1 mes)"


# Caso 2: Cambio de Dispositivo (Vehículo C cambió de dev X a dev Y)
vehicle_swap = Vehicle.create!(
  tenant: tenant,
  name: "Vehículo Swap C",
  license_plate: "SWAP-C03",
  status: "active",
  fuel_type: "gasoline"
)

# Viejo dispositivo (Inactivo)
VehicleProviderMapping.create!(
  vehicle: vehicle_swap,
  tenant_integration_configuration: geo_config,
  external_vehicle_id: "GEO-OLD-111",
  external_vehicle_name: "Dispositivo Viejo 111",
  is_active: false,
  mapped_at: 6.months.ago,
  valid_from: 6.months.ago,
  valid_until: 2.months.ago
)
puts "  ✓ Mapeo Histórico: #{vehicle_swap.license_plate} tuvo GEO-OLD-111"

# Nuevo dispositivo (Activo)
VehicleProviderMapping.create!(
  vehicle: vehicle_swap,
  tenant_integration_configuration: geo_config,
  external_vehicle_id: "GEO-NEW-222",
  external_vehicle_name: "Dispositivo Nuevo 222",
  is_active: true,
  mapped_at: 2.months.ago,
  valid_from: 2.months.ago,
  valid_until: nil
)
puts "  ✓ Mapeo Activo: #{vehicle_swap.license_plate} tiene GEO-NEW-222"

puts "✅ Datos de histórico generados correctamente."
