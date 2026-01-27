# frozen_string_literal: true

class LeasesController < ApplicationController
  def index
    @leases = Lease.all
  end

  def show
    @lease = Lease.find(params[:id])
  end

  def new
    @lease = Lease.new
  end

  def edit
    @lease = Lease.find(params[:id])
  end

  def create
    @lease = Lease.new(lease_params)

    if @lease.save
      redirect_to @lease, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    @lease = Lease.find(params[:id])
    if @lease.update(lease_params)
      redirect_to @lease, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @lease = Lease.find(params[:id])
    @lease.destroy
    redirect_to leases_url, notice: t(".success")
  end

  def terminate
    @lease = Lease.find(params[:id])
    if @lease.update(terminated_on: params[:terminated_on])
      redirect_to @lease, notice: t(".success")
    else
      redirect_to @lease, alert: @lease.errors.full_messages.join(", ")
    end
  end

  def renew
    @lease = Lease.find(params[:id])
    new_lease = ::LeaseRenewalService.new(@lease).call
    redirect_to new_lease, notice: t(".success")
  end

  private

  def lease_params
    params.expect(lease: %i[property_id tenant_id start_date duration_months rent_amount
                            security_deposit_in_months enhancement_period_months
                            enhancement_amount enhancement_type tax_name tax_rate])
  end
end
