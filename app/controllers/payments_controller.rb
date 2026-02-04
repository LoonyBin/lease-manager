# frozen_string_literal: true

class PaymentsController < ApplicationController
  def index
    @q = policy_scope(Payment).ransack(params[:q])
    @q.sorts = ["date desc", "created_at desc"] if @q.sorts.empty?
    @payments = @q.result.includes(:lease).page(params[:page]).per(20)
  end

  def new
    @payment = Payment.new
    authorize @payment
    @leases = policy_scope(Lease).includes(:property, :tenant)
  end

  def create
    @lease = Lease.find(payment_params[:lease_id])
    @payment = @lease.payments.build(payment_params.except(:lease_id))
    authorize @payment

    if @payment.save
      redirect_to payments_path, notice: t(".success")
    else
      @leases = policy_scope(Lease).includes(:property, :tenant)
      render :new, status: :unprocessable_content
    end
  end

  private

  def payment_params
    params.expect(payment: %i[lease_id date amount mode reference_number])
  end
end
