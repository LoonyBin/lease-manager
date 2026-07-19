# frozen_string_literal: true

# The reminder outbox: queued sends land here pending approval, and nothing
# leaves the app until an admin approves it.
class InvoiceNotificationsController < ApplicationController
  before_action :set_notification, only: %i[approve cancel retry]

  PER_PAGE = 25 # not configurable: matches the other index pages' page size

  # Authorized as well as scoped: a non-admin gets the standard denial rather
  # than an empty outbox that looks like there is nothing to approve.
  def index
    authorize InvoiceNotification, :index?
    @q = policy_scope(InvoiceNotification).ransack(search_params)
    @q.sorts = "occurrence_on desc" if @q.sorts.empty?
    results = @q.result
    # Computed on the whole filtered relation, not the current page, so the
    # bulk button does not vanish on a page that happens to hold no pending rows.
    @pending_matches = results.pending.exists?
    @notifications = results
                     .includes(:reminder_step, invoice: { lease: %i[property tenant] })
                     .page(params[:page]).per(PER_PAGE)
    respond_ok @notifications
  end

  def approve
    approved = transition(@notification, from: :pending, to: :approved)
    return respond_conflict(t(".not_pending")) unless approved

    SendInvoiceNotificationJob.perform_later(@notification)
    respond_updated(@notification) { redirect_back_or_to invoice_notifications_path, notice: t(".success") }
  end

  def cancel
    cancelled = transition(@notification, from: %i[pending failed], to: :cancelled)
    return respond_conflict(t(".not_cancellable")) unless cancelled

    respond_updated(@notification) { redirect_back_or_to invoice_notifications_path, notice: t(".success") }
  end

  def retry
    retried = transition(@notification, from: :failed, to: :pending, last_error: nil)
    return respond_conflict(t(".not_failed")) unless retried

    respond_updated(@notification) { redirect_back_or_to invoice_notifications_path, notice: t(".success") }
  end

  # Approves everything currently pending in the caller's scope, honouring
  # any active filter so "approve all" never reaches past what is on screen.
  def approve_all
    authorize InvoiceNotification, :approve_all?
    candidates = policy_scope(InvoiceNotification).ransack(search_params).result.pending.to_a
    # Each row is claimed individually, so a concurrent approve_all enqueues
    # the send job exactly once between them rather than once each.
    approved = candidates.select { |notification| transition(notification, from: :pending, to: :approved) }
    approved.each { |notification| SendInvoiceNotificationJob.perform_later(notification) }
    respond_updated(approved) do
      redirect_back_or_to invoice_notifications_path, notice: t(".success", count: approved.size)
    end
  end

  private

  # A conditional UPDATE rather than a read-then-write: only the request whose
  # write actually matched the expected status proceeds, so two admins clicking
  # Approve at once cannot both enqueue a send for the same reminder.
  # rubocop:disable Naming/PredicateMethod -- reports whether this caller won the transition
  def transition(notification, from:, to:, **attributes)
    statuses = InvoiceNotification.statuses
    expected = Array(from).map { |status| statuses.fetch(status.to_s) }
    updates = attributes.merge(status: statuses.fetch(to.to_s), updated_at: Time.current)
    # rubocop:disable Rails/SkipsModelValidations -- the conditional UPDATE is the lock
    changed = InvoiceNotification.where(id: notification.id, status: expected).update_all(updates)
    # rubocop:enable Rails/SkipsModelValidations
    return false unless changed == 1

    notification.reload
    true
  end
  # rubocop:enable Naming/PredicateMethod

  def set_notification
    @notification = policy_scope(InvoiceNotification).find(params.expect(:id))
    authorize @notification
  end

  # Only whitelisted predicates reach Ransack; `q` is otherwise free-form.
  def search_params
    params.fetch(:q, {}).permit(:status_eq, :channel_eq, :invoice_lease_id_eq, :occurrence_on_gteq,
                                :occurrence_on_lteq, :invoice_lease_tenant_name_cont, :s)
  end

  def respond_conflict(message)
    respond_to do |format|
      format.html { redirect_back_or_to invoice_notifications_path, alert: message }
      format.json { render json: { error: message }, status: :conflict }
    end
  end
end
