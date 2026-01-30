# frozen_string_literal: true

class PaymentsController < ApplicationController
  def index
    @payments = policy_scope(Payment).includes(:lease, :invoices).order(date: :desc, created_at: :desc)
  end

  def new
    @payment = Payment.new
    authorize @payment
    @leases = Lease.includes(:property, :tenant).all
  end

  # TODO: Refactor to push this down to model or service
  def create # rubocop:disable Metrics/AbcSize
    @lease = Lease.find(payment_params[:lease_id])
    @payment = @lease.payments.build(payment_params.except(:lease_id))
    authorize @payment

    if @payment.save
      PaymentService.new(@payment).call
      redirect_to payments_path, notice: t(".success")
    else
      @leases = Lease.includes(:property, :tenant).all
      render :new, status: :unprocessable_content
    end
  end

  private

  def payment_params
    params.expect(payment: %i[lease_id date amount mode reference_number])
  end
end
