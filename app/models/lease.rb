# frozen_string_literal: true

class Lease < ApplicationRecord
  include Lease::RentCalculation
  include Lease::Renewable
  include Lease::CapacityCheck

  belongs_to :property
  belongs_to :tenant
  has_many :invoices, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :entries, dependent: :destroy

  has_many_attached :documents

  after_create :handle_security_deposit_creation
  after_update :handle_security_deposit_termination, if: :saved_change_to_terminated_on?

  validates :start_date, presence: true
  validates :duration_months, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :termination_date_after_start_date

  def end_date
    return terminated_on if terminated_on.present?
    return nil unless start_date && duration_months

    (start_date + (duration_months - 1).months).end_of_month
  end

  def termination_date_after_start_date
    return if terminated_on.blank? || start_date.blank?

    return unless terminated_on <= start_date

    errors.add(:terminated_on, "must be after the start date")
  end

  def to_s
    "#{property.name}/#{start_date}(#{tenant.name})"
  end

  private

  def handle_security_deposit_creation
    SecurityDepositInvoicer.new(self).call
  end

  def handle_security_deposit_termination
    SecurityDepositInvoicer.new(self).call
  end
end
