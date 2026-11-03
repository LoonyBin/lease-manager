# frozen_string_literal: true

# One rung of a lease's reminder escalation ladder: when to chase (an offset
# from the invoice due date, optionally repeating), who to chase (a plain list
# of email addresses, so recipients need no user account), and what to say.
class ReminderStep < ApplicationRecord
  # Guards against a typo like `repeat_every_days: 0` scheduling forever and
  # against absurd offsets; both are validation bounds, not tuning knobs.
  MAX_OFFSET_DAYS = 365 # not configurable: an offset beyond a year is a data-entry error
  MAX_REPEATS_PER_STEP = 60 # not configurable: caps occurrence enumeration for one step

  belongs_to :lease
  has_many :invoice_notifications, dependent: :nullify

  scope :for_reminding_leases, -> { joins(:lease).merge(Lease.not_archived).merge(Lease.reminding) }

  validates :position, presence: true, numericality: { only_integer: true }
  validates :offset_days, presence: true,
                          numericality: { only_integer: true,
                                          greater_than_or_equal_to: -MAX_OFFSET_DAYS,
                                          less_than_or_equal_to: MAX_OFFSET_DAYS }
  validates :repeat_every_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :subject, presence: true
  validates :body, presence: true
  validate :must_have_recipients
  validate :recipient_emails_are_valid
  validate :message_placeholders_are_known

  # Accepts either an array or a comma/whitespace-separated string, so the
  # form can offer a single free-text field.
  def to_emails=(value)
    super(normalize_emails(value))
  end

  # The dates this step fires for an invoice, from the offset then every
  # +repeat_every_days+ while the invoice stays unsettled.
  def occurrences_for(due_date, up_to: Date.current)
    first = due_date + offset_days
    return first > up_to ? [] : [first] if repeat_every_days.blank?

    occurrences = []
    date = first
    while date <= up_to && occurrences.size < MAX_REPEATS_PER_STEP
      occurrences << date
      date += repeat_every_days
    end
    occurrences
  end

  # The latest firing that is already due, or nil when the step has not
  # come round yet. Only this one is materialised, so a lease that has been
  # overdue for a year does not flood the outbox with a whole backlog.
  #
  # Computed arithmetically rather than by walking +occurrences_for+, so an
  # invoice overdue past MAX_REPEATS_PER_STEP firings still reports its true
  # latest occurrence instead of silently stalling on a stale one.
  def latest_occurrence_for(due_date, up_to: Date.current)
    first = due_date + offset_days
    return nil if first > up_to
    return first if repeat_every_days.blank?

    elapsed_days = (up_to - first).to_i
    first + ((elapsed_days / repeat_every_days) * repeat_every_days)
  end

  def to_s
    label = if offset_days.negative?
              "#{offset_days.abs} days before due"
            elsif offset_days.zero?
              "On due date"
            else
              "#{offset_days} days after due"
            end
    repeat_every_days.present? ? "#{label}, repeating every #{repeat_every_days} days" : label
  end

  private

  def normalize_emails(value)
    Array(value.is_a?(String) ? value.split(/[,;\s]+/) : value)
      .map { |email| email.to_s.strip.downcase }
      .compact_blank
      .uniq
  end

  def must_have_recipients
    errors.add(:to_emails, "must include at least one email address") if to_emails.blank?
  end

  def recipient_emails_are_valid
    invalid = Array(to_emails).grep_v(URI::MailTo::EMAIL_REGEXP)
    errors.add(:to_emails, "contains invalid addresses: #{invalid.join(', ')}") if invalid.any?
  end

  def message_placeholders_are_known
    %i[subject body].each do |field|
      text = public_send(field)
      next if text.blank?

      unknown = InvoiceTemplates::TextRenderer.unknown_placeholders(text, Reminders::Context::VARIABLE_NAMES)
      errors.add(field, "references unknown placeholders: #{unknown.join(', ')}") if unknown.any?
    end
  end
end
