# db/seeds/financial_data.rb
module Seeds
  class FinancialData
    def self.run
      create_solred_configurations
      create_financial_transactions
      update_refuelings_with_source
    end

    private

    def self.create_solred_configurations
      puts "\n💳 Creando configuraciones de Solred..."

      acme = Tenant.find_by(slug: 'acme-corp')
      demo = Tenant.find_by(slug: 'demo-company')
      solred = IntegrationProvider.find_by(slug: 'solred')

      # Acme -> Solred (Activa)
      acme_solred = acme.tenant_integration_configurations.find_or_create_by!(
        integration_provider: solred
      ) do |config|
        config.credentials = {
          client_number: '0002601'
        }
        config.enabled_features = [ 'financial_import' ]
        config.sync_frequency = 'monthly'
        config.sync_hour = 9
        config.sync_day_of_month = 'start'
        config.is_active = true
        config.activated_at = 20.days.ago
        config.last_sync_at = 5.days.ago
        config.last_sync_status = 'success'
        config.sync_config = {
          file_format: 'excel',
          auto_reconcile: true
        }
        config.metadata = {
          setup_by: 'admin@acme.com',
          notes: 'Configuración de tarjetas Solred'
        }
      end
      puts "  ✓ #{acme.name} -> Solred (Activa, mensual día 1 a las 09:00)"

      # Demo -> Solred (Activa)
      demo_solred = demo.tenant_integration_configurations.find_or_create_by!(
        integration_provider: solred
      ) do |config|
        config.credentials = {
          client_number: '0000123'
        }
        config.enabled_features = [ 'financial_import' ]
        config.sync_frequency = 'monthly'
        config.sync_hour = 10
        config.sync_day_of_month = 'start'
        config.is_active = true
        config.activated_at = 30.days.ago
        config.last_sync_at = 3.days.ago
        config.last_sync_status = 'success'
        config.sync_config = {
          file_format: 'excel',
          is_demo: true
        }
        config.metadata = {
          is_demo: true
        }
      end
      puts "  ✓ #{demo.name} -> Solred (Activa, mensual día 1 a las 10:00)"

      puts "✅ #{TenantIntegrationConfiguration.where(integration_provider: solred).count} configuraciones de Solred creadas\n"
    end

    def self.create_financial_transactions
      puts "\n💰 Creando transacciones financieras (Solred)..."

      acme = Tenant.find_by(slug: 'acme-corp')
      demo = Tenant.find_by(slug: 'demo-company')
      solred_config_acme = TenantIntegrationConfiguration.find_by(
        tenant: acme,
        integration_provider: IntegrationProvider.find_by(slug: 'solred')
      )
      solred_config_demo = TenantIntegrationConfiguration.find_by(
        tenant: demo,
        integration_provider: IntegrationProvider.find_by(slug: 'solred')
      )

      # Transacciones de Acme (5 transacciones)
      acme_transactions = [
        { plate: '1234ABC', date: 25.days.ago, liters: 56.54, unit_price: 1.559, base: 88.15, discount: 7.35, total: 80.80, product: 'EFI 95', code: '003', card: '0007078830026010712' },
        { plate: '5678DEF', date: 20.days.ago, liters: 120.30, unit_price: 1.489, base: 179.09, discount: 15.50, total: 163.59, product: 'DIESEL', code: '001', card: '0007078830026010713' },
        { plate: '1234ABC', date: 15.days.ago, liters: 48.20, unit_price: 1.569, base: 75.63, discount: 6.20, total: 69.43, product: 'EFI 95', code: '003', card: '0007078830026010712' },
        { plate: '5678DEF', date: 10.days.ago, liters: 115.80, unit_price: 1.495, base: 173.12, discount: 14.80, total: 158.32, product: 'DIESEL', code: '001', card: '0007078830026010713' },
        { plate: '1234ABC', date: 5.days.ago, liters: 52.10, unit_price: 1.579, base: 82.27, discount: 7.10, total: 75.17, product: 'EFI 95', code: '003', card: '0007078830026010712' }
      ]

      acme_transactions.each_with_index do |tx, i|
        FinancialTransaction.create!(
          tenant: acme,
          tenant_integration_configuration: solred_config_acme,
          provider_slug: 'solred',
          vehicle_plate: tx[:plate],
          card_number: tx[:card],
          transaction_date: tx[:date],
          location_string: 'E.S. RALLY, S.A CTRA',
          product_code: tx[:code],
          product_name: tx[:product],
          quantity: tx[:liters],
          unit_price: tx[:unit_price],
          base_amount: tx[:base],
          discount_amount: tx[:discount],
          total_amount: tx[:total],
          currency: 'EUR',
          status: 'pending',
          provider_metadata: {
            num_refer: "#{1414853 + i}",
            cod_control: 'F',
            dcto_fijo: (tx[:discount] * 0.6).round(2),
            bonif_total: (tx[:discount] * 0.4).round(2),
            establecimiento_codigo: '183004225'
          }
        )
      end
      puts "  ✓ 5 transacciones de Acme creadas"

      # Transacciones de Demo (3 transacciones)
      demo_transactions = [
        { plate: 'DEMO001', date: 20.days.ago, liters: 60.00, unit_price: 1.550, base: 93.00, discount: 8.00, total: 85.00, product: 'DIESEL', code: '001', card: '0007078830099999' },
        { plate: 'DEMO001', date: 13.days.ago, liters: 55.50, unit_price: 1.560, base: 86.58, discount: 7.50, total: 79.08, product: 'DIESEL', code: '001', card: '0007078830099999' },
        { plate: 'DEMO001', date: 6.days.ago, liters: 58.20, unit_price: 1.570, base: 91.37, discount: 7.80, total: 83.57, product: 'DIESEL', code: '001', card: '0007078830099999' }
      ]

      demo_transactions.each_with_index do |tx, i|
        FinancialTransaction.create!(
          tenant: demo,
          tenant_integration_configuration: solred_config_demo,
          provider_slug: 'solred',
          vehicle_plate: tx[:plate],
          card_number: tx[:card],
          transaction_date: tx[:date],
          location_string: 'E.S. DEMO STATION',
          product_code: tx[:code],
          product_name: tx[:product],
          quantity: tx[:liters],
          unit_price: tx[:unit_price],
          base_amount: tx[:base],
          discount_amount: tx[:discount],
          total_amount: tx[:total],
          currency: 'EUR',
          status: 'pending',
          provider_metadata: {
            num_refer: "DEMO#{1000 + i}",
            cod_control: 'F',
            dcto_fijo: (tx[:discount] * 0.6).round(2),
            bonif_total: (tx[:discount] * 0.4).round(2),
            establecimiento_codigo: 'DEMO001'
          }
        )
      end
      puts "  ✓ 3 transacciones de Demo creadas"

      puts "✅ #{FinancialTransaction.count} transacciones financieras creadas\n"
    end

    def self.update_refuelings_with_source
      puts "\n🔄 Actualizando repostajes existentes con campo 'source'..."

      # Todos los repostajes existentes son de telemetría
      VehicleRefueling.where(source: nil).update_all(source: 0, is_reconciled: false)  # telemetry = 0

      puts "  ✓ #{VehicleRefueling.count} repostajes actualizados con source='telemetry'"

      # Todos los cargos eléctricos existentes son de telemetría
      VehicleElectricCharge.where(source: nil).update_all(source: 0, is_reconciled: false)  # telemetry = 0

      puts "  ✓ #{VehicleElectricCharge.count} cargos eléctricos actualizados con source='telemetry'"

      puts "✅ Campos 'source' actualizados\n"
    end
  end
end
