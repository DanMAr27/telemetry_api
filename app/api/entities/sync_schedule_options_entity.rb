# app/api/entities/sync_schedule_options_entity.rb
module Entities
  class SyncScheduleOptionsEntity < Grape::Entity
    expose :frequencies do
      [
        { value: "daily", label: "Diaria" },
        { value: "weekly", label: "Semanal" },
        { value: "monthly", label: "Mensual" }
      ]
    end
    expose :hours do
      (0..23).map { |h| { value: h, label: "#{h.to_s.rjust(2, '0')}:00" } }
    end
    expose :days_of_week do
      [
        { value: 0, label: "Domingo" },
        { value: 1, label: "Lunes" },
        { value: 2, label: "Martes" },
        { value: 3, label: "Miércoles" },
        { value: 4, label: "Jueves" },
        { value: 5, label: "Viernes" },
        { value: 6, label: "Sábado" }
      ]
    end
    expose :days_of_month do
      [
        { value: "start", label: "Primer día del mes" },
        { value: "end", label: "Último día del mes" }
      ]
    end
  end
end
