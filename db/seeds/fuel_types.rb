# db/seeds/fuel_types.rb
puts "Creating Standard Fuel Types..."

# Definición de tipos de combustible estándar
fuel_types = [
  { code: 'diesel', name: 'Diesel', energy_group: :fuel },
  { code: 'gasoline', name: 'Gasoline', energy_group: :fuel },
  { code: 'premium', name: 'Premium Gasoline', energy_group: :fuel },
  { code: 'lpg', name: 'LPG (Autogas)', energy_group: :fuel },
  { code: 'cng', name: 'CNG (Natural Gas)', energy_group: :fuel },
  { code: 'adblue', name: 'AdBlue', energy_group: :other },
  { code: 'electric', name: 'Electricity', energy_group: :electric },
  { code: 'other', name: 'Other', energy_group: :other }
]

fuel_types.each do |ft|
  FuelType.find_or_create_by!(code: ft[:code]) do |t|
    t.name = ft[:name]
    t.energy_group = ft[:energy_group]
  end
end

puts "✓ Created #{FuelType.count} fuel types"
