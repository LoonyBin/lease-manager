# frozen_string_literal: true

class TenantsController < ApplicationController
  def index
    @q = policy_scope(Tenant).ransack(params[:q])
    @tenants = @q.result.page(params[:page]).per(20)
    respond_ok @tenants
  end

  def show
    @tenant = Tenant.find(params.expect(:id))
    authorize @tenant
    respond_ok @tenant
  end

  def new
    @tenant = Tenant.new
    authorize @tenant
  end

  def edit
    @tenant = Tenant.find(params.expect(:id))
    authorize @tenant
  end

  def create
    @tenant = Tenant.new(tenant_params)
    authorize @tenant

    if @tenant.save
      respond_created(@tenant) { redirect_to @tenant, notice: t(".success") }
    else
      respond_invalid(@tenant) { render :new, status: :unprocessable_content }
    end
  end

  def update
    @tenant = Tenant.find(params.expect(:id))
    authorize @tenant
    if @tenant.update(tenant_params)
      respond_updated(@tenant) { redirect_to @tenant, notice: t(".success") }
    else
      respond_invalid(@tenant) { render :edit, status: :unprocessable_content }
    end
  end

  def destroy
    @tenant = Tenant.find(params.expect(:id))
    authorize @tenant
    @tenant.destroy
    respond_destroyed { redirect_to tenants_url, notice: t(".success") }
  end

  private

  def tenant_params
    params.expect(tenant: %i[name email phone_number])
  end
end
