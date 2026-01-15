# app/models/financial_transaction.rb
class FinancialTransaction < ApplicationRecord
  include SoftDeletable
  belongs_to :tenant
  belongs_to :integration_raw_data, optional: true
  belongs_to :tenant_integration_configuration
  belongs_to :product_catalog

  delegate :product_name, :product_code, :energy_type, :fuel_type, to: :product_catalog, allow_nil: true

  has_one :vehicle_refueling, dependent: :nullify
  has_one :vehicle_electric_charge, dependent: :nullify

  enum :status, {
    pending: "pending",       # Pendiente de conciliar
    matched: "matched",       # Conciliado con telemetría
    unmatched: "unmatched",   # Sin telemetría correspondiente
    ignored: "ignored"        # Marcado para ignorar (ej: peajes, lavados)
  }, prefix: :status

  validates :provider_slug, presence: true, length: { maximum: 50 }
  validates :transaction_date, presence: true
  validates :total_amount, presence: true, numericality: true
  validates :currency, length: { is: 3 }, allow_blank: true
  validates :status, presence: true
  validates :product_catalog, presence: true
  validates :match_confidence, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 100
  }, allow_nil: true

  validates :location_lat, numericality: {
    greater_than_or_equal_to: -90,
    less_than_or_equal_to: 90
  }, allow_nil: true

  validates :location_lng, numericality: {
    greater_than_or_equal_to: -180,
    less_than_or_equal_to: 180
  }, allow_nil: true

  scope :by_tenant, ->(tenant_id) { where(tenant_id: tenant_id) }
  scope :by_provider, ->(slug) { where(provider_slug: slug) }
  scope :by_vehicle, ->(plate) { where(vehicle_plate: plate) }
  scope :between_dates, ->(from, to) { where(transaction_date: from..to) }
  scope :recent, -> { order(transaction_date: :desc) }
  scope :this_month, -> { where("transaction_date >= ?", Time.current.beginning_of_month) }
  scope :this_year, -> { where("transaction_date >= ?", Time.current.beginning_of_year) }
  scope :pending_reconciliation, -> { where(status: "pending") }
  scope :reconciled, -> { where(status: "matched") }
  scope :unreconciled, -> { where(status: "unmatched") }

  scope :with_product_catalog, -> { joins(:product_catalog) }

  scope :fuel_transactions, -> {
    with_product_catalog.where(product_catalogs: { energy_type: [ :fuel, :electric ] })
  }

  scope :non_fuel_transactions, -> {
    with_product_catalog.where(product_catalogs: { energy_type: :other })
  }

  # ¿Tiene ubicación geográfica?
  def has_location?
    location_lat.present? && location_lng.present?
  end

  # Coordenadas como array
  def coordinates
    return nil unless has_location?
    [ location_lat, location_lng ]
  end

  # ¿Está conciliado con telemetría?
  def reconciled?
    status == "matched"
  end

  # ¿Es un gasto de combustible/electricidad?
  def is_fuel_transaction?
    return false unless product_catalog
    product_catalog.energy_fuel? || product_catalog.energy_electric?
  end

  # ¿Es un gasto no relacionado con combustible?
  def is_non_fuel_transaction?
    !is_fuel_transaction?
  end

  # Precio por litro/kWh calculado
  def calculated_unit_price
    return nil unless quantity.present? && quantity > 0 && total_amount.present?
    (total_amount / quantity).round(4)
  end

  # Descripción legible
  def description
    "#{product_name || 'Transacción'} - #{total_amount} #{currency} (#{transaction_date.strftime('%d/%m/%Y')})"
  end

  # Total gastado
  def self.total_amount_sum
    sum(:total_amount).to_f.round(2)
  end

  # Total de litros/kWh
  def self.total_quantity
    sum(:quantity).to_f.round(2)
  end

  # Precio promedio por litro/kWh
  def self.average_unit_price
    return 0 if total_quantity.zero?
    (total_amount_sum / total_quantity).round(4)
  end

  # Resumen por proveedor
  def self.summary_by_provider
    group(:provider_slug).select(
      "provider_slug",
      "COUNT(*) as transaction_count",
      "SUM(total_amount) as total_spent",
      "SUM(quantity) as total_quantity"
    )
  end

  # Resumen mensual
  def self.monthly_summary(year = Time.current.year)
    where("EXTRACT(YEAR FROM transaction_date) = ?", year)
      .group("EXTRACT(MONTH FROM transaction_date)")
      .select(
        "EXTRACT(MONTH FROM transaction_date) as month",
        "COUNT(*) as count",
        "SUM(total_amount) as total_amount",
        "SUM(quantity) as total_quantity"
      )
  end

  # SOFT DELETE CONFIGURATION

  # Relaciones que se desvinculan (FK = NULL) al borrar
  # Las relaciones vehicle_refueling y vehicle_electric_charge tienen dependent: :nullify
  # pero las gestionamos explícitamente aquí para tener control y auditoría
  def soft_delete_nullify_relations
    [
      { model: "VehicleRefueling", foreign_key: "financial_transaction_id", name: "Repostajes" },
      { model: "VehicleElectricCharge", foreign_key: "financial_transaction_id", name: "Cargas eléctricas" }
    ]
  end

  # Validaciones antes de borrar
  def soft_delete_validations
    validations = []

    if status_matched?
      validations << {
        severity: "blocker",
        message: "No se puede eliminar una transacción conciliada (matched)"
      }
    end

    validations
  end

  # Hook antes del borrado para guardar contexto
  def before_soft_delete(context)
    context[:status] = status
    context[:total_amount] = total_amount
    context[:transaction_date] = transaction_date
    context[:vehicle_plate] = vehicle_plate
    context[:has_refueling] = vehicle_refueling.present?
    context[:has_charge] = vehicle_electric_charge.present?
  end
end
