# frozen_string_literal: true

class LeasesController < ApplicationController
  def index
    @q = policy_scope(Lease).ransack(params[:q])
    @leases = @q.result.page(params[:page]).per(20)
  end

  def show
    @lease = Lease.includes(invoices: :line_items).find(params[:id])
    authorize @lease
  end

  def new
    if params[:renewed_from_id]
      old_lease = Lease.find(params[:renewed_from_id])
      @lease = Lease.build_renewal(old_lease)
    else
      @lease = Lease.new
    end
    authorize @lease
  end

  def edit
    @lease = Lease.find(params[:id])
    authorize @lease
  end

  def create
    @lease = Lease.new(lease_params)
    authorize @lease

    if @lease.save
      redirect_to @lease, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    @lease = Lease.find(params[:id])
    authorize @lease
    if @lease.update(lease_params)
      redirect_to @lease, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @lease = Lease.find(params[:id])
    authorize @lease
    @lease.destroy
    redirect_to leases_url, notice: t(".success")
  end

  private

  def lease_params
    params.expect(lease: [:property_id, :tenant_id, :start_date, :duration_months, :rent_amount,
                          :security_deposit_value, :security_deposit_type, :enhancement_period_months,
                          :enhancement_amount, :enhancement_type, :tax_name, :tax_rate, :terminated_on,
                          :renewed_from_id, :property_schedule, { documents: [] }])
  end
end
