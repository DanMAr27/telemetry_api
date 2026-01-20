# app/models/soft_delete_audit_log.rb
class SoftDeleteAuditLog < ApplicationRecord
  # Registro que fue borrado (polimórfico)
  belongs_to :record, polymorphic: true
  belongs_to :performed_by, polymorphic: true, optional: true

  validates :action, presence: true, inclusion: { in: %w[delete] }
  validates :performed_at, presence: true
  validates :cascade_count, numericality: { greater_than_or_equal_to: 0 }
  validates :nullify_count, numericality: { greater_than_or_equal_to: 0 }

  before_validation :ensure_context_is_hash

  scope :deletions, -> { where(action: "delete") }
  scope :recent, -> { order(performed_at: :desc) }
  scope :oldest, -> { order(performed_at: :asc) }
  scope :for_record, ->(record) { where(record: record) }
  scope :for_model, ->(model_class) { where(record_type: model_class.name) }
  scope :by_user, ->(user) { where(performed_by: user) }
  scope :massive_operations, -> { where("cascade_count > ? OR nullify_count > ?", 10, 10) }
  scope :with_cascades, -> { where("cascade_count > 0") }
  scope :with_nullify, -> { where("nullify_count > 0") }
  scope :between_dates, ->(from, to) { where(performed_at: from..to) }
  scope :last_days, ->(days) { where("performed_at >= ?", days.days.ago) }

  # ¿Tuvo impacto en cascada?
  def has_cascade_impact?
    cascade_count > 0
  end

  # ¿Tuvo impacto en nullify?
  def has_nullify_impact?
    nullify_count > 0
  end

  # Impacto total (cascadas + nullify)
  def total_impact
    cascade_count + nullify_count
  end

  # ¿Es una operación masiva?
  def massive_operation?
    total_impact > 10
  end

  def action_description
    "Eliminó #{record_type} ##{record_id}"
  end

  # Descripción del impacto
  def impact_description
    parts = []
    parts << "#{cascade_count} en cascada" if cascade_count > 0
    parts << "#{nullify_count} desvinculados" if nullify_count > 0
    return "Sin impacto adicional" if parts.empty?
    parts.join(", ")
  end

  # TODO: Información del usuario que realizó la acción
  def performed_by_description
    return "Sistema automático" unless performed_by
    "#{performed_by.class.name} ##{performed_by.id}"
  end

  class << self
    # Estadísticas generales simples
    def basic_stats
      {
        total_deletions: count,
        by_model: group(:record_type).count,
        cascade_impact: sum(:cascade_count),
        nullify_impact: sum(:nullify_count),
        massive_operations: massive_operations.count
      }
    end

    # Top modelos más borrados
    def top_deleted_models(limit = 10)
      group(:record_type)
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(limit)
        .count
    end

    # Operaciones recientes con impacto alto
    def recent_high_impact(days = 7, min_impact = 10)
      last_days(days)
        .where("cascade_count + nullify_count >= ?", min_impact)
        .order(performed_at: :desc)
    end
  end

  private

  def ensure_context_is_hash
    self.context = {} unless context.is_a?(Hash)
  end
end
