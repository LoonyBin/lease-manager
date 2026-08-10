# frozen_string_literal: true

class PaymentsController < ApplicationController
  include CorrectsPayments

  def index
    @q = policy_scope(Payment).ransack(params[:q])
    @q.sorts = ["date desc", "created_at desc"] if @q.sorts.empty?
    @payments = @q.result.includes(:lease).page(params[:page]).per(20)
    respond_ok @payments
  end

  def show
    @payment = Payment.find(params.expect(:id))
    authorize @payment
    respond_ok @payment
  end

  def new
    @payment = Payment.new(payment_params)
    authorize @payment
    @leases = filtered_leases
  end

  def edit
    @payment = Payment.find(params.expect(:id))
    authorize @payment, :update?
    @leases = edit_leases
  end

  def create
    @payment = build_payment
    authorize @payment

    if @payment.save
      respond_created(@payment) { redirect_to payments_path, notice: t(".success") }
    else
      @leases = filtered_leases
      respond_invalid(@payment) { render :new, status: :unprocessable_content }
    end
  end

  # A payment PATCH is one of three things, told apart by the submitted keys:
  #   status alone    -> the existing reject/confirm/reinstate transition
  #   editable fields -> a correction (re-inference; may move money)
  #   status + fields -> a confused client; refuse it (see reject_mixed_payload)
  def update
    @payment = Payment.find(params.expect(:id))
    authorize @payment

    keys = params.fetch(:payment, {}).keys.map(&:to_s)
    return respond_status_update if keys == %w[status]
    return reject_mixed_payload if keys.include?("status")

    correct_payment
  end

  private

  def respond_status_update
    if @payment.update(params.expect(payment: %i[status]))
      respond_updated(@payment) { redirect_to @payment, notice: t("payments.update.success") }
    else
      respond_invalid(@payment) { render :show, status: :unprocessable_content }
    end
  end

  def filtered_leases
    active = policy_scope(Lease).by_status("active")
    with_bal = policy_scope(Lease).where("cached_balance > 0")
    active.or(with_bal).includes(:property, :tenant)
  end

  def payment_params
    params.permit(payment: %i[lease_id date amount mode reference_number attachment payment_type])[:payment]
  end

  def build_payment
    @lease = Lease.find(payment_params[:lease_id])
    payment = @lease.payments.build(payment_params.except(:lease_id))
    payment.status = payment_status_for_user
    payment
  end

  def payment_status_for_user
    return :confirmed if current_user.admin?
    return :confirmed if owner_of_lease?

    :draft
  end

  def owner_of_lease?
    current_user.owners.exists?(id: @lease.property.owner_id)
  end
end
