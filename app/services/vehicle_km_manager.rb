class VehicleKmManager
  def initialize(vehicle)
    @vehicle = vehicle
  end

  def register_reading(input_date:, km_reported:, source_record: nil, **options)
    vehicle_km = @vehicle.vehicle_kms.build(
      input_date: input_date,
      km_reported: km_reported,
      source_record: source_record,
      status: :original
    )

    if vehicle_km.save
      update_vehicle_current_odometer(vehicle_km)
      ServiceResult.success(data: vehicle_km)
    else
      ServiceResult.failure(errors: vehicle_km.errors.full_messages)
    end
  end

  private

  def update_vehicle_current_odometer(vehicle_km)
    # Update vehicle's current odometer if the new reading is higher
    if @vehicle.current_odometer_km.nil? || vehicle_km.km_reported > @vehicle.current_odometer_km
      @vehicle.update(current_odometer_km: vehicle_km.km_reported)
    end
  end
end
