# frozen_string_literal: true

class LeasesController < ApplicationController
  def index
    base_scope = policy_scope(Lease)
    base_scope = base_scope.not_archived unless params.dig(:q, :by_status) == "archived"
    @q = base_scope.ransack(params[:q])
    @leases = @q.result.page(params[:page]).per(20)
  end

  def show
    @lease = Lease.find(params[:id])
    authorize @lease
    @statement_entries = helpers.statement_entries(@lease.entries.initial.preload(:instrument))
  end

  def new
    if params[:renewed_from_id]
      old_lease = Lease.find(params[:renewed_from_id])
      @lease = Lease.build_renewal(old_lease)
    else
      @lease = Lease.new(new_lease_prepopulate_params)
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

  def new_lease_prepopulate_params
    params.permit(lease: [:property_id])[:lease] || {}
  end

  def lease_params
    params.expect(lease: [:property_id, :tenant_id, :start_date, :duration_months, :rent_amount,
                          :security_deposit_value, :security_deposit_type, :enhancement_period_months,
                          :enhancement_amount, :enhancement_type, :tax_name, :tax_rate, :terminated_on,
                          :archived_at, :renewed_from_id, :property_schedule, :quantity, :payment_due_in,
                          { documents: [] }])
  end
end
