# frozen_string_literal: true

class PaymentsController < ApplicationController
  def index
    @q = policy_scope(Payment).ransack(params[:q])
    @q.sorts = ["date desc", "created_at desc"] if @q.sorts.empty?
    @payments = @q.result.includes(:lease).page(params[:page]).per(20)
  end

  def show
    @payment = Payment.find(params[:id])
    authorize @payment
  end

  def new
    @payment = Payment.new
    authorize @payment
    @leases = policy_scope(Lease).includes(:property, :tenant)
  end

  def create
    @payment = build_payment
    authorize @payment

    if @payment.save
      redirect_to payments_path, notice: t(".success")
    else
      @leases = policy_scope(Lease).includes(:property, :tenant)
      render :new, status: :unprocessable_content
    end
  end

  def update
    @payment = Payment.find(params[:id])
    authorize @payment

    if @payment.update(update_params)
      redirect_to @payment, notice: t(".success")
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def payment_params
    params.expect(payment: %i[lease_id date amount mode reference_number attachment])
  end

  def update_params
    params.expect(payment: %i[status])
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
