# frozen_string_literal: true

class Lease < ApplicationRecord
  include Lease::RentCalculation
  include Lease::Renewable
  include Lease::CapacityCheck

  VALID_STATUSES = %w[active expired terminated upcoming archived].freeze

  scope :not_archived, -> { where(archived_at: nil) }

  scope :by_status, lambda { |status|
    case status.to_s
    when "archived"
      where.not(archived_at: nil)
    when "terminated"
      where.not(terminated_on: nil).where(archived_at: nil)
    when "expired"
      where(terminated_on: nil)
        .where.not(duration_months: nil)
        .where("start_date + (duration_months * interval '1 month') < CURRENT_DATE")
    when "active"
      where(terminated_on: nil)
        .where("start_date <= CURRENT_DATE")
        .where(
          "duration_months IS NULL OR start_date + (duration_months * interval '1 month') >= CURRENT_DATE"
        )
    when "upcoming"
      where(terminated_on: nil)
        .where("start_date > CURRENT_DATE")
    else
      none
    end
  }

  def self.ransackable_scopes(*)
    %i[by_status]
  end

  belongs_to :property
  belongs_to :tenant
  has_many :invoices, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :entries, dependent: :destroy

  has_many_attached :documents

  before_validation :set_default_property_schedule

  after_create :handle_security_deposit_creation
  after_update :handle_security_deposit_termination, if: :saved_change_to_terminated_on?

  validates :start_date, presence: true
  validates :duration_months, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :termination_date_after_start_date
  validates :archived_at, absence: true, unless: :terminated_on?

  # rubocop:disable Rails/SkipsModelValidations -- Intentionally skip callbacks to avoid infinite loops
  def recalculate_cached_balance!
    update_column(:cached_balance, invoices.unsettled.sum(:balance))
  end
  # rubocop:enable Rails/SkipsModelValidations

  def archived?
    archived_at.present?
  end

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

  def set_default_property_schedule
    return if property_schedule.present?

    self.property_schedule = [property&.name, property&.address].compact_blank.join(", ")
  end

  def handle_security_deposit_creation
    SecurityDepositInvoicer.new(self).call
  end

  def handle_security_deposit_termination
    SecurityDepositInvoicer.new(self).call
  end
end
