# frozen_string_literal: true

module Payments
  # Corrects a mis-entered payment: applies an edit to any field and, when the
  # edit moves money, re-infers the affected leases so both the source and the
  # destination end up exactly as if the payment had been recorded correctly in
  # the first place. See #193.
  #
  # It orchestrates the primitives in Settlements::Deallocation — it does not
  # reimplement the unwind. The whole correction is atomic: a raise anywhere
  # leaves no partial ledger state observable.
  #
  #   deallocate(payment)    # unwind footprint + fully re-infer the SOURCE lease
  #   payment.update!(attrs) # move/edit; after_save rebuilds the initial on dest
  #   reallocate | reinfer   # settle the payment on the DESTINATION lease
  #
  # The destination branch depends on whether +date+ changed. A pure
  # lease/amount/type edit does not change chronological precedence, so the
  # create-time replay of +reallocate+ is faithful. A +date+ edit asserts a new
  # position in the queue that create-time replay cannot honour, so the whole
  # destination lease is re-inferred chronologically via
  # +reinfer_lease(audited: true)+ — never +readjust+, the unversioned bulk sweep.
  class Correction
    # Edits that move money: any of these on a live (confirmed_or_later) payment
    # invalidates its allocations and forces re-inference. Everything else
    # (mode, reference_number, attachment) is metadata and saves plainly.
    MONEY_MOVING_ATTRIBUTES = %w[lease_id amount date payment_type].freeze

    def self.call(payment, attrs)
      new(payment, attrs).call
    end

    def initialize(payment, attrs)
      @payment = payment
      @attrs = attrs.to_h.with_indifferent_access
      @warnings = []
    end

    attr_reader :warnings

    def call
      return apply_metadata_only if metadata_only?

      reinfer_around_edit
      self
    end

    private

    # A draft or rejected payment has no live footprint, and a metadata-only edit
    # moves no money, so both are a plain save with no re-inference. This also
    # keeps a draft/rejected off reallocate's rejected-payment guard.
    def metadata_only?
      !@payment.confirmed_or_later? || !money_moving?
    end

    def apply_metadata_only
      @payment.update!(@attrs)
      self
    end

    def reinfer_around_edit
      @source_lease = @payment.lease
      @source_balance_before = @source_lease.cached_balance.to_d
      date_reorders = changing?("date")

      ActiveRecord::Base.transaction do
        SettlementService.deallocate(@payment)
        @payment.update!(@attrs)
        reinfer_destination(date_reorders)
        compute_warnings
      end
    end

    def money_moving?
      MONEY_MOVING_ATTRIBUTES.any? { |attr| changing?(attr) }
    end

    def changing?(attr)
      return false unless @attrs.key?(attr)

      cast(attr, @attrs[attr]) != @payment.public_send(attr)
    end

    def cast(attr, value)
      @payment.class.type_for_attribute(attr).cast(value)
    end

    def reinfer_destination(date_reorders)
      if date_reorders
        Settlements::Deallocation.reinfer_lease(@payment.lease, audited: true)
      else
        SettlementService.reallocate(@payment)
      end
    end

    def compute_warnings
      dest = @payment.lease
      moved = @source_lease.id != dest.id

      add_warning(:different_tenant) if moved && dest.tenant_id != @source_lease.tenant_id
      add_warning(:date_outside_term) if date_outside_term?(dest)
      add_warning(:destination_inactive) if inactive?(dest)
      add_warning(:source_newly_outstanding) if moved && source_newly_outstanding?
    end

    def date_outside_term?(lease)
      return false if lease.start_date.blank?
      return true if @payment.date < lease.start_date

      end_date = lease.end_date
      end_date.present? && @payment.date > end_date
    end

    def inactive?(lease)
      lease.archived? || lease.terminated_on.present?
    end

    def source_newly_outstanding?
      @source_balance_before.zero? && @source_lease.reload.cached_balance.to_d.positive?
    end

    def add_warning(code)
      # i18n-tasks-use t('payments.correction.warnings.different_tenant')
      # i18n-tasks-use t('payments.correction.warnings.date_outside_term')
      # i18n-tasks-use t('payments.correction.warnings.destination_inactive')
      # i18n-tasks-use t('payments.correction.warnings.source_newly_outstanding')
      @warnings << { code: code.to_s, message: I18n.t("payments.correction.warnings.#{code}") }
    end
  end
end
