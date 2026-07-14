# frozen_string_literal: true

class InvoiceTemplate < ApplicationRecord
  belongs_to :lease
  has_many :line_items, -> { order(:position, :id) },
           class_name: "InvoiceTemplateLineItem",
           inverse_of: :invoice_template,
           dependent: :destroy
  has_many :invoices, dependent: :nullify

  accepts_nested_attributes_for :line_items, allow_destroy: true

  scope :for_active_leases, -> { joins(:lease).merge(Lease.not_archived) }

  validates :name, presence: true
  validates :payment_due_in, presence: true
  validate :payment_due_in_non_negative
  validate :ends_on_not_before_starts_on
  validate :must_have_line_items

  # Generation window start; nil follows the lease start date dynamically.
  def effective_starts_on
    starts_on || lease.start_date
  end

  # Generation window end; nil follows the lease end date and an explicit
  # date is still capped by it (terminations shrink the window automatically).
  def effective_ends_on
    [ends_on, lease.end_date].compact.min
  end

  # Whether the effective window overlaps the month containing +date+.
  def generates_for?(date)
    month_start = date.beginning_of_month
    start_on = effective_starts_on
    return false if start_on.nil? || start_on > month_start.end_of_month

    end_on = effective_ends_on
    end_on.nil? || end_on >= month_start
  end

  def to_s
    name
  end

  private

  def payment_due_in_non_negative
    return if payment_due_in.blank?

    errors.add(:payment_due_in, "must be non-negative") if payment_due_in.to_i.negative?
  end

  def ends_on_not_before_starts_on
    return if starts_on.blank? || ends_on.blank?

    errors.add(:ends_on, "must be on or after the start date") if ends_on < starts_on
  end

  def must_have_line_items
    return if line_items.reject(&:marked_for_destruction?).any?

    errors.add(:base, "must have at least one line item")
  end
end
