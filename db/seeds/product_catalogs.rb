# db/seeds/product_catalogs.rb
# Catálogo completo de productos Solred

solred = IntegrationProvider.find_by(slug: 'solred')

if solred
  puts "Creating Solred product catalog..."

  products = [
    # COMBUSTIBLES
    { code: '012', name: 'EFITEC 95 N', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '912', name: 'EFITEC 95 N', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '001', name: 'DIESEL TEST', energy_type: 'fuel', fuel_type: 'diesel' }, # Used in seeds
    { code: '012', name: 'EFITEC 98 N', energy_type: 'fuel', fuel_type: 'premium' },
    { code: '012', name: 'EFITEC 98 N', energy_type: 'fuel', fuel_type: 'premium' },
    { code: '912', name: 'EFITEC 98 N', energy_type: 'fuel', fuel_type: 'premium' },
    { code: '013', name: 'EFITEC N C', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '913', name: 'EFITEC N C', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '063', name: 'AUTO ESTRADA', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '963', name: 'AUTO ESTRADA', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '110', name: 'ADBLUE', energy_type: 'other', fuel_type: nil },
    { code: '110', name: 'ARLA32/ADBLUE', energy_type: 'other', fuel_type: nil },
    { code: '117', name: 'EFITEC 95 N', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '113', name: 'CASCO ECO (PORTUGAL)', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '113', name: 'DIESEL C-10 N', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '913', name: 'CASCO ECO (PORTUGAL)', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '011', name: 'LUBRICANTE', energy_type: 'other', fuel_type: nil },
    { code: '010', name: 'LUBRICANTE 2', energy_type: 'other', fuel_type: nil },
    { code: '070', name: 'CASCO ECO (CANARIAS)', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '970', name: 'CASCO ECO (CANARIAS)', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '015', name: 'DIESEL E+10', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '915', name: 'DIESEL E+10', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '031', name: 'CASCO LEVA', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '128', name: 'EFITEC 95', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '028', name: 'EFITEC 95', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '129', name: 'CANGAS', energy_type: 'other', fuel_type: nil },
    { code: '005', name: 'EFITEC 95 LF', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '905', name: 'EFITEC 95 LF', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '1237', name: 'Oleo Max Gasoil', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '1237', name: 'Gasolina 95 (P)', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '1237', name: 'Gasolina 98 (P)', energy_type: 'fuel', fuel_type: 'premium' },
    { code: '329', name: 'DIESEL MOTOR', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '129', name: 'ADICCIONES', energy_type: 'other', fuel_type: nil },
    { code: '1235', name: 'ADBLUE (P)', energy_type: 'other', fuel_type: nil },
    { code: '1235', name: 'Gasolina (S)', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '1235', name: 'Oleo Max Gasoil', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '1535', name: 'Oleo Evo Gasoil(AR)', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '1235', name: 'Oleo Evo (P)', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '1237', name: 'Oleo Evo Gasoil', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '701', name: 'DIESEL (GIB)', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '707', name: 'Gasolina (Gib)', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '705', name: 'Otras compras', energy_type: 'other', fuel_type: nil },

    # ELÉCTRICOS
    { code: '003', name: 'AUTOGAS (GLP)', energy_type: 'fuel', fuel_type: 'lpg' },
    { code: '903', name: 'AUTOGAS (GLP)', energy_type: 'fuel', fuel_type: 'lpg' },
    { code: '083', name: 'TALLER', energy_type: 'other', fuel_type: nil },
    { code: '147', name: 'GASOIL OA', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '128', name: 'EFITEC 98 N', energy_type: 'fuel', fuel_type: 'premium' },
    { code: '185', name: 'EFITEC N E-2', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '985', name: 'EFITEC N E-2', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '995', name: 'AUTOGAS (GLP)', energy_type: 'fuel', fuel_type: 'lpg' },
    { code: '979', name: 'DIESEL E+10', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '117', name: 'EFITEC 95-3', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '420', name: 'CASCO GASOIL-2', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '420', name: 'EFITEC 95-2', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '442', name: 'Oleo Max GASOIL-2', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '309', name: 'EFITEC E+-1', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '909', name: 'EFITEC E+-1', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '304', name: 'Gasolina 95', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '007', name: 'EFITEC N', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '907', name: 'EFITEC N', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '714515', name: 'GNC-2', energy_type: 'fuel', fuel_type: 'cng' },
    { code: '714515', name: 'GNC-3', energy_type: 'fuel', fuel_type: 'cng' },
    { code: '714514', name: 'GNC-3', energy_type: 'fuel', fuel_type: 'cng' },
    { code: '714515', name: 'GNC MAS', energy_type: 'fuel', fuel_type: 'cng' },
    { code: '004', name: 'Premium Diesel', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '904', name: 'Premium Diesel', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '018', name: 'Oleo Max Gasoil-A-55', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '918', name: 'Oleo Max Gasoil-A-55', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '010', name: 'Ultimate Gasolina A', energy_type: 'fuel', fuel_type: 'premium' },
    { code: '911', name: 'Ultimate Gasolina-B', energy_type: 'fuel', fuel_type: 'premium' },
    { code: '114', name: 'ADBLUE', energy_type: 'other', fuel_type: nil },
    { code: '014', name: 'ADBLUE PLUS', energy_type: 'other', fuel_type: nil },
    { code: '914', name: 'ADBLUE PLUS', energy_type: 'other', fuel_type: nil },
    { code: '180', name: 'Gasolina y gasoy 95', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '714305', name: 'GNC-1', energy_type: 'fuel', fuel_type: 'cng' },
    { code: '1236', name: 'Oleo Max Gasolinado', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '326', name: 'Gasolina Gasolinaf', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '211', name: 'GASOLINERAS', energy_type: 'other', fuel_type: nil },
    { code: '212', name: 'Gasolina 98 (S)', energy_type: 'fuel', fuel_type: 'premium' },
    { code: '129', name: 'C-100 POWER', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '187', name: 'Adblue (gasolinera)', energy_type: 'other', fuel_type: nil },
    { code: '185', name: 'EFITEC N E-2', energy_type: 'fuel', fuel_type: 'diesel' },
    { code: '118', name: 'G.P. EFITEC-95', energy_type: 'fuel', fuel_type: 'gasoline' },
    { code: '714305', name: 'GNC EFITEC-3', energy_type: 'fuel', fuel_type: 'cng' },

    # RECARGA ELÉCTRICA
    { code: '008', name: 'RECARGA ELECTRICA', energy_type: 'electric', fuel_type: nil },

    # OTROS SERVICIOS
    { code: '129', name: 'LAVADO', energy_type: 'other', fuel_type: nil },
    { code: '083', name: 'TALLER', energy_type: 'other', fuel_type: nil },
    { code: '211', name: 'GASOLINERAS', energy_type: 'other', fuel_type: nil },
    { code: '098', name: 'AUTOPISTAS', energy_type: 'other', fuel_type: nil }
  ]

  products.each do |p|
    ProductCatalog.find_or_create_by!(
      integration_provider: solred,
      product_code: p[:code],
      product_name: p[:name]
    ) do |catalog|
      catalog.energy_type = p[:energy_type]
      # Map legacy enum fuel_type to new FuelType relationship
      if p[:fuel_type].present?
        # Clean naming mapping (e.g. 'gasoline' -> 'gasoline')
        ft_code = p[:fuel_type]
        catalog.fuel_type = FuelType.find_by(code: ft_code)
      end
      catalog.is_active = true
    end
  end

  puts "✓ Created #{ProductCatalog.by_provider(solred.id).count} products for Solred"
end
