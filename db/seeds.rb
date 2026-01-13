# db/seeds.rb
# Main seed file - Generates complete test environment
# Run with: rails db:seed

puts "\n" + "=" * 80
puts "TELEMETRY API - COMPREHENSIVE SEED DATA"
puts "=" * 80

# Clean existing data to ensure a fresh start
if Rails.env.development?
  puts "\n🗑️  Cleaning existing data..."

  # Order matters due to foreign keys (Dependents FIRST)
  VehicleElectricCharge.delete_all
  VehicleRefueling.delete_all
  FinancialTransaction.delete_all

  IntegrationRawData.delete_all
  IntegrationSyncExecution.delete_all

  ProductCatalog.delete_all
  CardVehicleMapping.delete_all
  VehicleProviderMapping.delete_all
  Vehicle.delete_all

  TenantIntegrationConfiguration.delete_all
  Tenant.delete_all

  # Static data - usually better to keep
  IntegrationAuthSchema.delete_all
  IntegrationFeature.delete_all
  # IntegrationProvider.delete_all

  puts "✅ Data cleaned"
end

# Load individual seed files in order
# NOTE: Order is important!!
seed_files = [
  'fuel_types',               # 0. Standard Fuel Types (NEW)
  'integrations',             # 1. Base Providers (Geotab, Solred)
  'product_catalogs',         # 2. Product Catalog (Fuel codes)
  'comprehensive_test_setup', # 3. UNIFIED Test Data & Excel Generation
  'vehicle_mapping_history'   # 4. Historical Mappings (Recycled IDs case)
]

seed_files.each do |seed_file|
  seed_path = Rails.root.join('db', 'seeds', "#{seed_file}.rb")

  if File.exist?(seed_path)
    puts "\n🌱 Loading: #{seed_file}.rb"
    load seed_path

    # Run the class if it's the comprehensive setup
    if seed_file == 'comprehensive_test_setup'
      ComprehensiveTestSeed.new.run
    end
  else
    puts "\n⚠️  Skipping: #{seed_file}.rb (not found)"
  end
end

puts "\n" + "=" * 80
puts "✅ SEED COMPLETED"
puts "=" * 80
puts "\n📊 Database Summary:"
puts "  Tenants: #{Tenant.count}"
puts "  Vehicles: #{Vehicle.count}"
puts "  Vehicle Refuelings: #{VehicleRefueling.count}"
puts "  Electric Charges: #{VehicleElectricCharge.count}"
puts "  Product Catalog: #{ProductCatalog.count}"
puts "  Integration Providers: #{IntegrationProvider.count}"
puts "  Tenant Configurations: #{TenantIntegrationConfiguration.count}"

puts "\n🎯 Ready for Testing:"
puts "  1. Solred Excel file: public/Operaciones_Test_Solred.xlsx"
puts "  2. Swagger UI: http://localhost:3000/swagger"
puts "  3. Upload endpoint: POST /api/v1/integration_configurations/{id}/files"

solred_config = TenantIntegrationConfiguration.joins(:integration_provider)
  .where(integration_providers: { slug: 'solred' }).first

if solred_config
  puts "\n📋 Solred Configuration ID: #{solred_config.id}"
  puts "  Use this ID in Swagger for file upload and reconciliation"
end

puts "\n" + "=" * 80 + "\n"
