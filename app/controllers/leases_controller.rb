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

    ActiveRecord::Base.transaction do
      terminate_old_lease_for_renewal if renewing?
      save_lease_or_render_form
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
    @renewing_from = Lease.find(params[:id])
    @lease = Lease.new(renewal_attributes)
    render :renew
  end

  private

  def lease_params
    params.expect(lease: %i[property_id tenant_id start_date duration_months rent_amount
                            security_deposit_in_months enhancement_period_months
                            enhancement_amount enhancement_type tax_name tax_rate])
  end

  def renewing?
    params[:renewing_from_id].present?
  end

  def terminate_old_lease_for_renewal
    old_lease = Lease.find(params[:renewing_from_id])
    old_lease.update!(terminated_on: @lease.start_date - 1.day)
  end

  def save_lease_or_render_form
    if @lease.save
      redirect_to @lease, notice: renewing? ? t("leases.renew.success") : t("leases.create.success")
    else
      handle_create_failure
    end
  end

  def handle_create_failure
    @renewing_from = Lease.find(params[:renewing_from_id]) if renewing?
    render(renewing? ? :renew : :new, status: :unprocessable_content)
    raise ActiveRecord::Rollback
  end

  def renewal_attributes
    renewal_base_attributes.merge(renewal_enhancement_attributes).merge(renewal_tax_attributes)
  end

  def renewal_base_attributes
    {
      property: @renewing_from.property,
      tenant: @renewing_from.tenant,
      start_date: @renewing_from.end_date + 1.day,
      duration_months: @renewing_from.duration_months,
      rent_amount: @renewing_from.current_rent_at(@renewing_from.end_date),
      security_deposit_in_months: @renewing_from.security_deposit_in_months
    }
  end

  def renewal_enhancement_attributes
    {
      enhancement_period_months: @renewing_from.enhancement_period_months,
      enhancement_amount: @renewing_from.enhancement_amount,
      enhancement_type: @renewing_from.enhancement_type
    }
  end

  def renewal_tax_attributes
    { tax_name: @renewing_from.tax_name, tax_rate: @renewing_from.tax_rate }
  end
end
