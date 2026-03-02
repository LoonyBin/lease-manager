# frozen_string_literal: true

class GenerateInvoicesJob < ApplicationJob
  queue_as :default

  def perform
    BatchInvoiceGenerator.new.call
  end
end
