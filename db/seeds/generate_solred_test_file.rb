# Script para generar archivo Excel de prueba Solred
# Ejecutar con: rails runner db/seeds/generate_solred_test_file.rb

begin
  require 'write_xlsx'
rescue LoadError
  puts "⚠️  Gem 'write_xlsx' not installed. Skipping Excel file generation."
  puts "   To generate the Excel file, run: gem install write_xlsx"
  puts "   Then run: rails runner db/seeds/generate_solred_test_file.rb"
  exit 0
end

puts "Generating Solred test Excel file..."

# Crear workbook (xlsx format)
workbook = WriteXLSX.new('public/Operaciones_Test_Solred.xlsx')
worksheet = workbook.add_worksheet

# Formato para texto (evita que Excel convierta a número)
text_format = workbook.add_format(num_format: '@')

# Headers según plantilla real Solred
headers = [
  'NOM_EMPR', 'DIR_EMPR', 'POB_EMPR', 'COD_POSTAL', 'COD_PROV', 'NIF_EMPR',
  'COD_CLI', 'NUM_SERFAC', 'ANO_FACTUR', 'NUM_FACTUR', 'FEC_FACTUR',
  'NUM_TARJET', 'MATRICULA', 'CONDUCTOR', 'NUM_REFER', 'FEC_OPERAC',
  'HOR_OPERAC', 'NOM_ESTABL', 'COD_PROVES', 'POB_ESTABL', 'KILOMETROS',
  'DES_PRODU', 'NUM_LITROS', 'MONEDA', 'IMPORTE', 'TIP_OPERAC',
  'COD_ESTABL', 'IVA', 'COD_PRODU', 'VIU', 'PU_LITRO', 'DCTO_FIJO',
  'DCTO_EESS', 'DCTO_OPERAC', 'RAPPEL', 'BONIF_TOTAL', 'IMP_TOTAL',
  'COD_CONTROL', 'R_AUT', 'PRECIO_LITRO', 'INFO_AUXILIAR'
]

# Escribir headers
headers.each_with_index do |header, col|
  worksheet.write(0, col, header)
end

# Obtener tenant (Test Company o el primero disponible para desarrollo)
tenant = Tenant.find_by(name: 'Test Company') || Tenant.first
puts "Using Tenant: #{tenant.name} (ID: #{tenant.id})" if tenant

vehicles = Vehicle.where(tenant: tenant, license_plate: [ '3554MWK', '8389LYG', '3560MWK', 'EV001' ]) if tenant

if vehicles && vehicles.any?
  base_date = 3.days.ago
  row = 1

  # Definir productos para testing
  products = [
    { code: '003', name: 'EFI 95', type: :fuel },           # Gasolina 95
    { code: '004', name: 'EFI 98', type: :fuel },           # Gasolina 98
    { code: '001', name: 'DIESEL', type: :fuel },           # Diesel
    { code: '008', name: 'RECARGA ELECTRICA', type: :electric }  # Eléctrico
  ]

  vehicles.each_with_index do |vehicle, idx|
    # Determinar si es vehículo eléctrico
    is_electric = vehicle.license_plate == 'EV001'

    # Crear 5 transacciones por vehículo
    5.times do |i|
      # Semilla determinista para coincidir con generate_matching_telemetry.rb
      srand(idx * 100 + i)

      transaction_date = base_date + (idx * 12).hours + (i * 6).hours

      # Seleccionar producto según tipo de vehículo
      if is_electric
        product = products.find { |p| p[:type] == :electric }
        quantity = rand(20.0..40.0).round(2)  # kWh
        unit_price = 0.35  # €/kWh
      else
        # Alternar entre diferentes combustibles
        fuel_products = products.select { |p| p[:type] == :fuel }
        product = fuel_products[i % fuel_products.length]
        quantity = rand(30.0..60.0).round(2)  # Litros
        unit_price = product[:code] == '001' ? 1.45 : 1.559  # Diesel más barato
      end

      base_amount = (quantity * unit_price).round(2)
      discount = (base_amount * 0.05).round(2)
      total = (base_amount - discount).round(2)

      data = [
        'FERROCARRILS DE LA GENERALITAT DE C',           # NOM_EMPR
        'CARRER DELS VERGOS, 44',                        # DIR_EMPR
        'BARCELONA',                                      # POB_EMPR
        '08017',                                          # COD_POSTAL
        'BARCELONA',                                      # COD_PROV
        'Q0801576J',                                      # NIF_EMPR
        '0002601',                                        # COD_CLI
        'A',                                              # NUM_SERFAC
        '2025',                                           # ANO_FACTUR
        "0122#{row.to_s.rjust(4, '0')}",                 # NUM_FACTUR
        transaction_date.strftime('%Y%m%d'),              # FEC_FACTUR
        "000707883002601#{vehicle.id.to_s.rjust(4, '0')}", # NUM_TARJET
        vehicle.license_plate,                            # MATRICULA
        '',                                               # CONDUCTOR
        row.to_s.rjust(6, '0'),                          # NUM_REFER
        transaction_date.strftime('%Y%m%d'),              # FEC_OPERAC
        transaction_date.strftime('%H%M'),                # HOR_OPERAC
        'E.S. TEST STATION',                              # NOM_ESTABL
        '08',                                             # COD_PROVES
        'BARCELONA',                                      # POB_ESTABL
        '0',                                              # KILOMETROS
        product[:name],                                   # DES_PRODU
        quantity,                                         # NUM_LITROS
        '978',                                            # MONEDA
        base_amount,                                      # IMPORTE
        'V',                                              # TIP_OPERAC
        '183050970',                                      # COD_ESTABL
        '21',                                             # IVA
        product[:code],                                   # COD_PRODU
        '0',                                              # VIU
        unit_price.round(3),                              # PU_LITRO
        '13,00',                                          # DCTO_FIJO
        '0,00',                                           # DCTO_EESS
        '0,00',                                           # DCTO_OPERAC
        '0,00',                                           # RAPPEL
        discount.round(2),                                # BONIF_TOTAL
        total,                                            # IMP_TOTAL
        'F',                                              # COD_CONTROL
        '0',                                              # R_AUT
        '000,000',                                        # PRECIO_LITRO
        ''                                                # INFO_AUXILIAR
      ]

      data.each_with_index do |value, col|
        # Columnas que deben ser texto para preservar ceros a la izquierda:
        # COD_PRODU (col 28), NUM_TARJET (col 11), COD_POSTAL (col 3), etc.
        text_columns = [ 3, 11, 28 ]  # COD_POSTAL, NUM_TARJET, COD_PRODU

        if text_columns.include?(col)
          worksheet.write_string(row, col, value.to_s, text_format)
        else
          worksheet.write(row, col, value)
        end
      end

      row += 1
    end
  end

  workbook.close
  puts "✓ Created test file: public/Operaciones_Test_Solred.xlsx"
  puts "✓ #{row - 1} transactions for #{vehicles.count} vehicles"
  puts ""
  puts "Vehicles in file:"
  vehicles.each do |v|
    vehicle_type = v.license_plate == 'EV001' ? 'Electric' : 'Fuel'
    puts "  - #{v.license_plate} (ID: #{v.id}, Type: #{vehicle_type}, Card: 000707883002601#{v.id.to_s.rjust(4, '0')})"
  end
  puts ""
  puts "Products included:"
  puts "  - Gasolina 95 (003)"
  puts "  - Gasolina 98 (004)"
  puts "  - Diesel (001)"
  puts "  - Recarga Eléctrica (008)"
  puts ""
  puts "📋 Next steps:"
  puts "1. Upload file via Swagger: POST /api/v1/integration_configurations/{id}/files"
  puts "2. Check reconciliation results automatically"
else
  puts "⚠ No vehicles found. Please run vehicle seeds first:"
  puts "   rails runner db/seeds/reconciliation_test_data.rb"
end
