# app/api/entities/file_upload_response_entity.rb
module Entities
  class FileUploadResponseEntity < Grape::Entity
    expose :sync_execution_id, documentation: { type: "Integer", desc: "ID de la ejecución de sincronización" }
    expose :status, documentation: { type: "String", desc: "Estado del procesamiento" }
    expose :file_name, documentation: { type: "String", desc: "Nombre del archivo procesado" }
    expose :file_size, documentation: { type: "Integer", desc: "Tamaño del archivo en bytes" }
    expose :records_processed, documentation: { type: "Integer", desc: "Número de registros procesados" }
    expose :records_failed, documentation: { type: "Integer", desc: "Número de registros fallidos" }
    expose :duration_seconds, documentation: { type: "Integer", desc: "Duración del procesamiento en segundos" }
    expose :errors, documentation: { type: "string", is_array: true, desc: "Lista de errores encontrados" }
    expose :summary, documentation: { type: "String", desc: "Resumen del procesamiento" }
    expose :reconciliation, documentation: { type: "Hash", desc: "Estadísticas de reconciliación automática" }
  end
end
