# frozen_string_literal: true

class ScheduleInvoiceRemindersJob < ApplicationJob
  queue_as :default

  def perform
    Reminders::BatchScheduler.new.call
  end
end
