class CreateSoftDeleteAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :soft_delete_audit_logs do |t|
      # Registro que fue borrado/restaurado (polimórfico)
      t.references :record, polymorphic: true, null: false, index: true

      # Usuario que realizó la acción (polimórfico, opcional)
      t.references :performed_by, polymorphic: true, null: true

      # Acción realizada: 'delete' o 'restore'
      t.string :action, null: false, limit: 20

      # Snapshot del estado del registro al momento del borrado
      t.jsonb :context, default: {}, null: false

      # Contadores de impacto
      t.integer :cascade_count, default: 0, null: false
      t.integer :nullify_count, default: 0, null: false

      # Metadata de restauración
      t.boolean :can_restore, default: true, null: false
      t.string :restore_complexity, limit: 20 # 'simple', 'medium', 'complex'

      # Timestamp de la acción
      t.datetime :performed_at, null: false

      t.timestamps
    end

    # Índices para optimizar consultas
    add_index :soft_delete_audit_logs, :action
    add_index :soft_delete_audit_logs, :performed_at
    add_index :soft_delete_audit_logs, :can_restore

    # Índice compuesto para búsquedas por modelo y fecha
    add_index :soft_delete_audit_logs,
              [ :record_type, :action, :performed_at ],
              name: "index_audit_logs_on_record_type_action_date"

    # Índice para búsquedas por usuario
    add_index :soft_delete_audit_logs,
              [ :performed_by_type, :performed_by_id, :performed_at ],
              name: "index_audit_logs_on_user_date"

    # Índice parcial para operaciones masivas
    add_index :soft_delete_audit_logs,
              :cascade_count,
              where: "cascade_count > 10",
              name: "index_audit_logs_on_high_cascade"
  end
end
