# app/models/concerns/soft_deletable.rb
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    include Discard::Model

     before_discard :execute_soft_delete_workflow
    after_discard :execute_after_soft_delete_workflow
  end

  class_methods do
    # Borrado seguro con validaciones y análisis de impacto
    def soft_delete_with_validation(id, options = {})
      record = find(id)
      coordinator = SoftDelete::DeletionCoordinator.new(record, options)
      coordinator.call
    end

    # Análisis de impacto sin ejecutar el borrado
    def deletion_impact_for(id)
      record = find(id)
      record.deletion_impact
    end
  end

  # Relaciones que se borran EN CASCADA al borrar este registro
  def soft_delete_cascade_relations
    []
  end

  # Relaciones que IMPIDEN el borrado si tienen registros activos
  def soft_delete_blocking_relations
    []
  end

  # Relaciones que se desvinculan (FK = NULL) al borrar
  def soft_delete_nullify_relations
    []
  end

  # Validaciones personalizadas antes de borrar
  def soft_delete_validations
    []
  end

  # Hook ejecutado ANTES del borrado
  def before_soft_delete(context)
    # Override en cada modelo si es necesario
  end

  # Hook ejecutado DESPUÉS del borrado
  def after_soft_delete(context)
    # Override en cada modelo si es necesario
  end

  # Analiza el impacto de borrar este registro
  def deletion_impact
    @deletion_impact ||= SoftDelete::ImpactAnalyzer.new(self).analyze
  end

  # ¿Se puede borrar este registro?
  def can_be_deleted?
    deletion_impact[:can_delete]
  end

  # Fuerza el borrado limpiando el cache de impacto
  def recalculate_deletion_impact
    @deletion_impact = nil
    deletion_impact
  end

  private

  # Ejecuta el workflow completo antes de marcar como discarded
  def execute_soft_delete_workflow
    @deletion_context = build_deletion_context

    # PASO 1: Validaciones de negocio del modelo
    validation_errors = normalize_validations(soft_delete_validations)

    blockers = validation_errors.select { |v| v[:severity] == "blocker" }
    if blockers.any?
      blockers.each { |error| errors.add(:base, error[:message]) }
      throw :abort
    end

    # PASO 2: Verificar relaciones bloqueantes
    if has_blocking_relations?
      errors.add(:base, blocking_relations_message)
      throw :abort
    end

    # PASO 3: Hook pre-borrado (el modelo puede agregar al contexto)
    before_soft_delete(@deletion_context)

    # PASO 4: Procesar cascadas
    process_cascade_relations

    # PASO 5: Procesar nullify
    process_nullify_relations

    true
  rescue StandardError => e
    Rails.logger.error("[SOFT DELETE ERROR] #{self.class.name}##{id}: #{e.message}")
    errors.add(:base, "Error interno: #{e.message}")
    throw :abort
  end

  # Ejecuta acciones después del borrado
  def execute_after_soft_delete_workflow
    log_deletion
    after_soft_delete(@deletion_context)
    @deletion_context = nil
  end

  # Procesa relaciones en cascada
  def process_cascade_relations
    cascade_count = 0

    soft_delete_cascade_relations.each do |config|
      relation_name = config[:name]

      # Verificar condición si existe
      if config[:condition].is_a?(Proc)
        next unless instance_exec(&config[:condition])
      end

      # Si es opcional, saltar (se maneja en el coordinador)
      next if config[:optional]

      begin
        relation = send(relation_name)

        # Manejar relaciones has_many
        if relation.respond_to?(:each)
          records = relation.respond_to?(:kept) ? relation.kept : relation
          records.each do |record|
            if record.respond_to?(:discard)
              record.discard
              cascade_count += 1
            end
          end
        # Manejar relaciones belongs_to o has_one
        elsif relation && relation.respond_to?(:discard)
          relation.discard
          cascade_count += 1
        end
      rescue StandardError => e
        Rails.logger.error(
          "[CASCADE ERROR] #{self.class.name}##{id} -> #{relation_name}: #{e.message}"
        )
      end
    end

    @deletion_context[:cascade_count] = cascade_count
  end

  # Procesa relaciones nullify (desvinculación)
  def process_nullify_relations
    nullify_count = 0

    soft_delete_nullify_relations.each do |config|
      model_class = config[:model].constantize
      foreign_key = config[:foreign_key]

      # Buscar registros que referencian a este
      records = model_class.kept.where(foreign_key => id)
      affected_count = records.count

      if affected_count > 0
        records.update_all(foreign_key => nil)
        nullify_count += affected_count

        Rails.logger.info(
          "[NULLIFY] #{affected_count} registros de #{config[:model]} " \
          "desvinculados de #{self.class.name}##{id}"
        )
      end
    end

    @deletion_context[:nullify_count] = nullify_count
  end

  # Verifica si existen relaciones que bloquean el borrado
  def has_blocking_relations?
    soft_delete_blocking_relations.any? do |config|
      relation_name = config[:name]

      begin
        relation = send(relation_name)

        if relation.respond_to?(:kept)
          relation.kept.exists?
        elsif relation.respond_to?(:exists?)
          relation.exists?
        else
          relation.present?
        end
      rescue StandardError
        false
      end
    end
  end

  # Construye mensaje de error para relaciones bloqueantes
  def blocking_relations_message
    messages = soft_delete_blocking_relations.map do |config|
      relation_name = config[:name]
      custom_message = config[:message]

      begin
        relation = send(relation_name)
        count = if relation.respond_to?(:kept)
                  relation.kept.count
        elsif relation.respond_to?(:count)
                  relation.count
        else
                  1
        end

        if custom_message
          "#{count} #{custom_message}"
        else
          "#{count} #{relation_name.to_s.humanize.downcase} activos"
        end
      rescue StandardError
        relation_name.to_s.humanize.downcase
      end
    end

    "No se puede eliminar: tiene #{messages.join(', ')}"
  end

  # Normaliza validaciones a formato estándar
  def normalize_validations(validations)
    validations.map do |validation|
      if validation.is_a?(String)
        severity = if validation.include?("ADVERTENCIA")
                     "warning"
        elsif validation.include?("CRÍTICO") || validation.include?("BLOQUEADO")
                     "blocker"
        else
                     "info"
        end

        { severity: severity, message: validation }
      elsif validation.is_a?(Hash)
        validation[:severity] ||= "info"
        validation
      else
        { severity: "info", message: validation.to_s }
      end
    end
  end

  # Construye el contexto inicial para el borrado
  def build_deletion_context
    {
      model: self.class.name,
      record_id: id,
      deleted_at: Time.current,
      cascade_count: 0,
      nullify_count: 0,
      performed_by: instance_variable_get(:@deletion_user)
    }
  end

  # Registra el borrado en auditoría
  def log_deletion
    SoftDeleteAuditLog.create!(
      record: self,
      action: "delete",
      context: @deletion_context,
      cascade_count: @deletion_context[:cascade_count],
      nullify_count: @deletion_context[:nullify_count],
      performed_at: @deletion_context[:deleted_at],
      performed_by: @deletion_context[:performed_by],
      can_restore: true,
      restore_complexity: calculate_restore_complexity
    )
  rescue StandardError => e
    Rails.logger.error(
      "[AUDIT ERROR] No se pudo registrar el borrado de #{self.class.name}##{id}: #{e.message}"
    )
  end

  # Calcula la complejidad de restauración basada en cascadas
  def calculate_restore_complexity
    cascade_count = @deletion_context[:cascade_count] || 0

    return "simple" if cascade_count == 0
    return "medium" if cascade_count < 10
    "complex"
  end
end
