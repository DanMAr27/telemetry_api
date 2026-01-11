# db/seeds/comprehensive_test_setup.rb
require 'write_xlsx'

class ComprehensiveTestSeed
  def initialize
    @scenarios = []
    # Estructura para almacenar tenants y sus configs
    @tenants = {}
  end

  def run
    puts "\n🏁 INICIANDO SEED MAESTRO DE PRUEBA (MULTI-TENANT)"
    puts "=" * 80

    clean_data
    setup_infrastructure
    define_scenarios
    create_db_data
    generate_excel_file

    puts "\n✨ MASTER SEED COMPLETADO"
    puts "=" * 80
  end

  private

  def clean_data
    puts "\n🗑️  Limpiando base de datos..."
    # Limpieza más agresiva pero segura para desarrollo
    if Rails.env.development?
      FinancialTransaction.destroy_all
      VehicleElectricCharge.destroy_all
      VehicleRefueling.destroy_all
      IntegrationRawData.destroy_all
      IntegrationSyncExecution.destroy_all
      CardVehicleMapping.destroy_all
      VehicleProviderMapping.destroy_all
      Vehicle.destroy_all
      TenantIntegrationConfiguration.destroy_all
      Tenant.destroy_all
      puts "✓ Base de datos limpia"
    end
  end

  def setup_infrastructure
    puts "\n🏗️  Configurando tenants e integraciones..."

    # Providers (asegurar que existen)
    geotab = IntegrationProvider.find_by!(slug: 'geotab')
    solred = IntegrationProvider.find_by!(slug: 'solred')

    # -------------------------------------------------------------
    # TENANT A: "Acme Corp" (Full Integration)
    # Tiene Geotab (Telemetría) y Solred (Financiero)
    # -------------------------------------------------------------
    t1 = Tenant.create!(name: 'Acme Corp', slug: 'acme-corp', status: 'active')
    c1_geo = TenantIntegrationConfiguration.create!(
      tenant: t1, integration_provider: geotab, is_active: true,
      enabled_features: [ 'fuel', 'battery' ],
      credentials: { database: 'acme', username: 'admin', password: 'pwd' }
    )
    c1_sol = TenantIntegrationConfiguration.create!(
      tenant: t1, integration_provider: solred, is_active: true,
      enabled_features: [ 'financial_import' ],
      credentials: { client_code: '0002601' } # Código Cliente A
    )
    @tenants[:acme] = { tenant: t1, geotab: c1_geo, solred: c1_sol, client_code: '0002601' }
    puts "  ✓ Tenant A: Acme Corp (Full)"

    # -------------------------------------------------------------
    # TENANT B: "Logistics MX" (Solo Telemetría)
    # Tiene Geotab pero NO Solred configurado (simula error de config)
    # -------------------------------------------------------------
    t2 = Tenant.create!(name: 'Logistics MX', slug: 'logistics-mx', status: 'active')
    c2_geo = TenantIntegrationConfiguration.create!(
      tenant: t2, integration_provider: geotab, is_active: true,
      enabled_features: [ 'fuel' ],
      credentials: { database: 'logistics', username: 'admin', password: 'pwd' }
    )
    @tenants[:logistics] = { tenant: t2, geotab: c2_geo, solred: nil, client_code: '0009999' }
    puts "  ✓ Tenant B: Logistics MX (Solo Telemetría)"

    # -------------------------------------------------------------
    # TENANT C: "Solred Only S.L." (Solo Financiero)
    # No tiene telemetría (Caso de uso: Importar gastos sin reconciliar)
    # -------------------------------------------------------------
    t3 = Tenant.create!(name: 'Solred Only S.L.', slug: 'solred-only', status: 'active')
    c3_sol = TenantIntegrationConfiguration.create!(
      tenant: t3, integration_provider: solred, is_active: true,
      enabled_features: [ 'financial_import' ],
      credentials: { client_code: '0005555' }
    )
    @tenants[:solred_only] = { tenant: t3, geotab: nil, solred: c3_sol, client_code: '0005555' }
    puts "  ✓ Tenant C: Solred Only (Sin Telemetría)"
  end

  def define_scenarios
    base_date = 2.days.ago.beginning_of_day + 8.hours

    @scenarios = []

    # =========================================================================
    # ESCENARIOS TENANT A (ACME) - CASOS DE RECONCILIACIÓN VARIADOS
    # =========================================================================

    # 1. Match Diesel Perfecto
    @scenarios << {
      tenant_key: :acme, plate: "ACME-D01", type: :fuel,
      desc: "Match Diesel Perfecto",
      product: '001', qty: 50.0, price: 1.45, date: base_date,
      telemetry: { exists: true, offset: 10, qty_diff: 0 }
    }

    # 2. Match Gasolina 95
    @scenarios << {
      tenant_key: :acme, plate: "ACME-G95", type: :fuel,
      desc: "Match Gasolina 95",
      product: '003', qty: 45.0, price: 1.559, date: base_date + 30.minutes,
      telemetry: { exists: true, offset: 5, qty_diff: 0 }
    }

    # 3. Match Gasolina 98
    @scenarios << {
      tenant_key: :acme, plate: "ACME-G98", type: :fuel,
      desc: "Match Gasolina 98 Premium",
      product: '004', qty: 40.0, price: 1.65, date: base_date + 1.hour,
      telemetry: { exists: true, offset: -8, qty_diff: 0 }
    }

    # 4. Match EV Perfecto
    @scenarios << {
      tenant_key: :acme, plate: "ACME-EV1", type: :electric,
      desc: "Match Carga Eléctrica",
      product: '008', qty: 45.0, price: 0.40, date: base_date + 1.5.hours,
      telemetry: { exists: true, offset: -5, qty_diff: 0 }
    }

    # 5. Match EV 2
    @scenarios << {
      tenant_key: :acme, plate: "ACME-EV2", type: :electric,
      desc: "Match Carga Eléctrica Rápida",
      product: '008', qty: 60.0, price: 0.45, date: base_date + 2.hours,
      telemetry: { exists: true, offset: 12, qty_diff: 0 }
    }

    # 6. Unmatched por Cantidad (Diesel)
    @scenarios << {
      tenant_key: :acme, plate: "ACME-D02", type: :fuel,
      desc: "Unmatch Diesel (Cantidad Excel 60L vs Tel 40L)",
      product: '001', qty: 60.0, price: 1.45, date: base_date + 2.5.hours,
      telemetry: { exists: true, offset: 0, qty_diff: -20 }
    }

    # 7. Unmatched por Tiempo (Gasolina)
    @scenarios << {
      tenant_key: :acme, plate: "ACME-G95-2", type: :fuel,
      desc: "Unmatch Gasolina 95 (Tiempo >3h)",
      product: '003', qty: 35.0, price: 1.559, date: base_date + 3.hours,
      telemetry: { exists: true, offset: 185, qty_diff: 0 }
    }

    # 8. Unmatched Sin Telemetría (Diesel)
    @scenarios << {
      tenant_key: :acme, plate: "ACME-D03", type: :fuel,
      desc: "Unmatch Diesel (Sin Telemetría)",
      product: '001', qty: 55.0, price: 1.45, date: base_date + 4.hours,
      telemetry: { exists: false }
    }

    # 9. Unmatched Sin Telemetría (EV)
    @scenarios << {
      tenant_key: :acme, plate: "ACME-EV3", type: :electric,
      desc: "Unmatch EV (Sin Telemetría)",
      product: '008', qty: 30.0, price: 0.40, date: base_date + 4.5.hours,
      telemetry: { exists: false }
    }

    # 10. AdBlue (Otro producto - debería ignorarse o procesarse según lógica)
    @scenarios << {
      tenant_key: :acme, plate: "ACME-D01", type: :fuel,
      desc: "AdBlue (Producto Otro)",
      product: '110', qty: 10.0, price: 0.95, date: base_date + 5.hours,
      telemetry: { exists: false }
    }

    # 11. Lavado (Ignorado)
    @scenarios << {
      tenant_key: :acme, plate: "ACME-D01", type: :fuel,
      desc: "Lavado (Ignorado)",
      product: '129', qty: 1.0, price: 10.0, date: base_date + 5.5.hours,
      telemetry: { exists: false }
    }

    # 12. Diesel con descuento
    @scenarios << {
      tenant_key: :acme, plate: "ACME-D04", type: :fuel,
      desc: "Match Diesel con Descuento",
      product: '001', qty: 70.0, price: 1.40, date: base_date + 6.hours,
      telemetry: { exists: true, offset: 15, qty_diff: 0 }
    }

    # =========================================================================
    # ESCENARIOS TENANT B (LOGISTICS) - SIN CONFIG SOLRED
    # =========================================================================

    @scenarios << {
      tenant_key: :logistics, plate: "LOG-D01", type: :fuel,
      desc: "Logistics: Diesel (Unidentified en Acme)",
      product: '001', qty: 100.0, price: 1.45, date: base_date + 7.hours,
      telemetry: { exists: true, offset: 0, qty_diff: 0 }
    }

    # =========================================================================
    # ESCENARIOS TENANT C (SOLRED ONLY) - SIN TELEMETRÍA
    # =========================================================================

    @scenarios << {
      tenant_key: :solred_only, plate: "SOL-D01", type: :fuel,
      desc: "SolredOnly: Diesel (Siempre Unmatched)",
      product: '001', qty: 25.0, price: 1.45, date: base_date + 8.hours,
      telemetry: { exists: false }
    }

    # =========================================================================
    # CASOS DE BORDE GLOBALES
    # =========================================================================

    @scenarios << {
      tenant_key: nil, plate: "GHOST-99", type: :fuel,
      desc: "Matrícula Inexistente",
      product: '001', qty: 10.0, price: 1.45, date: base_date + 9.hours,
      client_code: '0002601',
      telemetry: { exists: false }
    }
  end

  def create_db_data
    puts "\n💾 Generando datos densos en DB..."

    # Crear SyncExecutions para cada tenant con Geotab
    syncs = {}
    @tenants.each do |key, data|
      next unless data[:geotab] # Solo si tiene Geotab

      # Sync Completada (Ayer)
      IntegrationSyncExecution.create!(
        tenant_integration_configuration: data[:geotab],
        feature_key: 'fuel',
        status: 'completed',
        started_at: 1.day.ago,
        finished_at: 1.day.ago + 10.minutes,
        duration_seconds: 600,
        records_processed: 50
      )

      # Sync Actual (Running - simula job en curso)
      IntegrationSyncExecution.create!(
        tenant_integration_configuration: data[:geotab],
        feature_key: 'real_time_location', # Otra feature
        status: 'running',
        started_at: 5.minutes.ago
      )

      # Sync Fallida (Hace 2 días)
      IntegrationSyncExecution.create!(
        tenant_integration_configuration: data[:geotab],
        feature_key: 'fuel',
        status: 'failed',
        started_at: 2.days.ago,
        finished_at: 2.days.ago + 1.minute,
        duration_seconds: 60,
        error_message: "Connection timeout exception",
        records_failed: 50
      )

      # Sync activa para los datos de prueba de hoy
      syncs[key] = IntegrationSyncExecution.create!(
        tenant_integration_configuration: data[:geotab],
        feature_key: 'fuel', # Generico
        status: 'completed',
        started_at: 2.hours.ago,
        finished_at: 1.hour.ago,
        duration_seconds: 3600,
        records_processed: 0
      )
    end

    @scenarios.each do |s|
      tenant_data = s[:tenant_key] ? @tenants[s[:tenant_key]] : nil

      # 1. Crear Vehículo (si aplica)
      vehicle = nil
      if tenant_data
        vehicle = Vehicle.find_or_create_by!(tenant: tenant_data[:tenant], license_plate: s[:plate]) do |v|
          v.name = "#{s[:plate]} #{s[:type].to_s.humanize}"
          v.brand = 'TestBrand'
          v.model = 'Model X'
          v.fuel_type = s[:type] == :electric ? 'electric' : 'diesel'
          v.is_electric = s[:type] == :electric
        end

        # 1.1 Crear VehicleProviderMapping (Geotab)
        if tenant_data[:geotab]
          VehicleProviderMapping.find_or_create_by!(
            vehicle: vehicle,
            tenant_integration_configuration: tenant_data[:geotab],
            external_vehicle_id: "geo_#{s[:plate]}"
          ) do |m|
            m.external_vehicle_name = "Geotab #{s[:plate]}"
            m.is_active = true
            m.mapped_at = Time.current
          end
        end

        # 1.2 Crear CardVehicleMapping (Solred)
        if tenant_data[:solred]
          # Generar sufijo de tarjeta basado en placa (mismo que en excel)
          card_suffix = Zlib.crc32(s[:plate]).to_s[-4..-1]
          full_card = "000707883002601#{card_suffix}"

          CardVehicleMapping.find_or_create_by!(
            tenant: tenant_data[:tenant],
            integration_provider: tenant_data[:solred].integration_provider, # Mapping es por provider, no config
            card_number: full_card
          ) do |m|
            m.vehicle = vehicle
            m.is_active = true
            m.valid_from = 1.year.ago
            m.valid_until = 1.year.from_now
          end
        end
      end

      # 2. Crear Datos Telemetría (Raw + Record)
      if s[:telemetry] && s[:telemetry][:exists] && tenant_data && tenant_data[:geotab]
        t_offs = s[:telemetry][:offset].minutes
        q_diff = s[:telemetry][:qty_diff]

        real_date = s[:date] + t_offs
        real_qty = s[:qty] + q_diff

        raw = IntegrationRawData.create!(
          integration_sync_execution: syncs[s[:tenant_key]],
          tenant_integration_configuration: tenant_data[:geotab],
          provider_slug: 'geotab',
          feature_key: s[:type] == :electric ? 'battery' : 'fuel',
          external_id: "geo_raw_#{s[:plate]}_#{s[:date].to_i}",
          raw_data: { test_case: s[:desc] },
          processing_status: 'normalized',
          normalized_at: Time.current
        )

        if s[:type] == :electric
          VehicleElectricCharge.create!(
            tenant: tenant_data[:tenant],
            vehicle: vehicle,
            integration_raw_data: raw,
            charge_start_time: real_date,
            charge_end_time: real_date + 45.minutes,
            energy_consumed_kwh: real_qty,
            location_lat: 40.0, location_lng: -3.0,
            source: 'telemetry'
          )
        else
          VehicleRefueling.create!(
            tenant: tenant_data[:tenant],
            vehicle: vehicle,
            integration_raw_data: raw,
            refueling_date: real_date,
            volume_liters: real_qty,
            odometer_km: 50000,
            location_lat: 40.0, location_lng: -3.0,
            source: 'telemetry'
          )
        end
      end
    end

    # Llamar a generación masiva
    generate_bulk_data(syncs)

    puts "  ✓ Registros DB creados para #{@scenarios.count} escenarios + datos masivos"
  end

  def generate_bulk_data(syncs)
    # =========================================================================
    # GENERACIÓN MASIVA DE DATOS DE RELLENO (BACKGROUND NOISE)
    # =========================================================================
    puts "  🎲 Generando datos masivos de relleno..."

    # 1. Histórico de Transacciones Financieras (Ya conciliadas)
    # Simula que el sistema lleva funcionando un tiempo.
    20.times do |i|
      date = 1.month.ago + i.days
      plate = "HIST-#{i.to_s.rjust(3, '0')}"

      # Vehículo histórico
      v = Vehicle.create!(
        tenant: @tenants[:acme][:tenant],
        name: "Historic Vehicle #{i}",
        license_plate: plate,
        status: 'active',
        fuel_type: 'diesel'
      )

      # Transacción histórica ya conciliada
      ft = FinancialTransaction.create!(
        tenant: @tenants[:acme][:tenant], # Tenant Acme
        tenant_integration_configuration: @tenants[:acme][:solred],
        provider_slug: 'solred',
        transaction_date: date,
        total_amount: 50.0,
        status: 'matched', # Ya conciliada
        match_confidence: 100
      )

      # Telemetría histórica asociada
      VehicleRefueling.create!(
        tenant: @tenants[:acme][:tenant],
        vehicle: v,
        refueling_date: date,
        volume_liters: 40.0,
        financial_transaction: ft,
        source: 'telemetry',
        is_reconciled: true
      )
    end
    puts "  ✓ 20 Transacciones históricas conciliadas creadas"

    # 2. Vehículos sin actividad reciente (Flota parada)
    10.times do |i|
      Vehicle.create!(
        tenant: @tenants[:acme][:tenant],
        name: "Idle Vehicle #{i}",
        license_plate: "IDLE-#{i.to_s.rjust(3, '0')}",
        status: 'active',
        fuel_type: 'diesel'
      )
    end
    puts "  ✓ 10 Vehículos inactivos creados"

    # 3. Datos Raw Huérfanos (Errores de proceso previos)
    5.times do |i|
      IntegrationRawData.create!(
        integration_sync_execution: syncs[:acme],
        tenant_integration_configuration: @tenants[:acme][:geotab],
        provider_slug: 'geotab',
        feature_key: 'fuel',
        external_id: "orphan_raw_#{i}",
        raw_data: { error: "corrupted_data" },
        processing_status: 'failed', # Falló al procesar
        normalization_error: "Invalid JSON structure"
      )
    end
    puts "  ✓ 5 Registros Raw fallidos creados"
  end

  def generate_excel_file
    puts "\n📄 Generando Excel Multi-Tenant..."
    filename = 'public/Operaciones_Test_Solred.xlsx'
    workbook = WriteXLSX.new(filename)
    worksheet = workbook.add_worksheet

    header_fmt = workbook.add_format(bold: 1, bg_color: '#EEEEEE', border: 1)

    # Headers exactos proporcionados por el usuario
    headers = [
      'NOM_EMPR', 'DIR_EMPR', 'POB_EMPR', 'COD_POSTAL', 'COD_PROV', 'NIF_EMPR', 'COD_CLI',
      'NUM_SERFAC', 'ANO_FACTUR', 'NUM_FACTUR', 'FEC_FACTUR', 'NUM_TARJET', 'MATRICULA',
      'CONDUCTOR', 'NUM_REFER', 'FEC_OPERAC', 'HOR_OPERAC', 'NOM_ESTABL', 'COD_PROVES', 'POB_ESTABL',
      'KILOMETROS', 'DES_PRODU', 'NUM_LITROS', 'MONEDA', 'IMPORTE', 'TIP_OPERAC', 'COD_ESTABL',
      'IVA', 'COD_PRODU', 'VIU', 'PU_LITRO', 'DCTO_FIJO', 'DCTO_EESS', 'DCTO_OPERAC',
      'RAPPEL', 'BONIF_TOTAL', 'IMP_TOTAL', 'COD_CONTROL', 'R_AUT', 'PRECIO_LITRO', 'INFO_AUXILIAR'
    ]

    headers.each_with_index { |h, i| worksheet.write(0, i, h, header_fmt) }

    row = 1

    # Process both specific scenarios and bulk data (if we had a way to store bulk rows,
    # but for now we iterate scenarios. For bulk mass, we'd need to add them to a list.
    # To keep it simple, I'll generate rows for scenarios first).

    @scenarios.each do |s|
      client_code = s[:client_code] || (s[:tenant_key] ? @tenants[s[:tenant_key]][:client_code] : '0002601')

      base_amount = (s[:qty] * s[:price]).round(2)
      discount = 0.0
      total = base_amount

      prod_name = case s[:product]
      when '001' then 'DIESEL A'
      when '003' then 'EFI 95'
      when '008' then 'RECARGA EV'
      when '129' then 'LAVADO'
      else 'OTRO'
      end

      # Mapeo Columna a Columna
      worksheet.write(row, 0, 'FERROCARRILS DE LA GENERALITAT DE C') # NOM_EMPR
      worksheet.write(row, 1, 'CARRER DELS VERGOS, 44')              # DIR_EMPR
      worksheet.write(row, 2, 'BARCELONA')                           # POB_EMPR
      worksheet.write(row, 3, '08017')                              # COD_POSTAL
      worksheet.write(row, 4, 'BARCELONA')                           # COD_PROV
      worksheet.write(row, 5, 'Q0801576J')                          # NIF_EMPR
      worksheet.write(row, 6, client_code)                          # COD_CLI
      worksheet.write(row, 7, 'A')                                  # NUM_SERFAC
      worksheet.write(row, 8, s[:date].strftime('%Y'))              # ANO_FACTUR
      worksheet.write(row, 9, "0122#{row.to_s.rjust(4, '0')}")     # NUM_FACTUR
      worksheet.write(row, 10, s[:date].strftime('%Y%m%d'))         # FEC_FACTUR

      # Tarjeta
      card_suffix = Zlib.crc32(s[:plate]).to_s[-4..-1]
      worksheet.write(row, 11, "000707883002601#{card_suffix}")     # NUM_TARJET

      worksheet.write(row, 12, s[:plate])                           # MATRICULA
      worksheet.write(row, 13, '')                                  # CONDUCTOR
      worksheet.write(row, 14, row.to_s.rjust(6, '0'))             # NUM_REFER
      worksheet.write(row, 15, s[:date].strftime('%Y%m%d'))        # FEC_OPERAC (como string YYYYMMDD)
      worksheet.write_string(row, 16, s[:date].strftime('%H%M'))   # HOR_OPERAC (como string para preservar ceros)
      worksheet.write(row, 17, 'E.S. TEST STATION')                 # NOM_ESTABL
      worksheet.write(row, 18, '17')                                # COD_PROVES
      worksheet.write(row, 19, 'MADRID')                            # POB_ESTABL
      worksheet.write(row, 20, 0)                                   # KILOMETROS
      worksheet.write(row, 21, prod_name)                           # DES_PRODU
      worksheet.write_number(row, 22, s[:qty])                      # NUM_LITROS
      worksheet.write(row, 23, '978')                               # MONEDA (EUR)
      worksheet.write_number(row, 24, base_amount)                  # IMPORTE
      worksheet.write(row, 25, 'V')                                 # TIP_OPERAC
      worksheet.write(row, 26, '123456')                            # COD_ESTABL
      worksheet.write(row, 27, '21')                                # IVA
      worksheet.write_string(row, 28, s[:product])                  # COD_PRODU
      worksheet.write(row, 29, '0')                                 # VIU
      worksheet.write_number(row, 30, s[:price])                    # PU_LITRO
      worksheet.write_number(row, 31, 0.0)                          # DCTO_FIJO
      worksheet.write_number(row, 32, 0.0)                          # DCTO_EESS
      worksheet.write_number(row, 33, 0.0)                          # DCTO_OPERAC
      worksheet.write_number(row, 34, 0.0)                          # RAPPEL
      worksheet.write_number(row, 35, 0.0)                          # BONIF_TOTAL
      worksheet.write_number(row, 36, total)                        # IMP_TOTAL
      worksheet.write(row, 37, 'F')                                 # COD_CONTROL
      worksheet.write(row, 38, '0')                                 # R_AUT
      worksheet.write_number(row, 39, s[:price])                    # PRECIO_LITRO (Igual a PU_LITRO para simpleza)
      worksheet.write(row, 40, '')                                  # INFO_AUXILIAR

      row += 1
    end

    workbook.close
    puts "✓ Archivo generado: #{filename}"
  end
end
