# frozen_string_literal: true

class TenantsController < ApplicationController
  def index
    @q = policy_scope(Tenant).ransack(params[:q])
    @tenants = @q.result.page(params[:page]).per(20)
  end

  def show
    @tenant = Tenant.find(params[:id])
    authorize @tenant
  end

  def new
    @tenant = Tenant.new
    authorize @tenant
  end

  def edit
    @tenant = Tenant.find(params[:id])
    authorize @tenant
  end

  def create
    @tenant = Tenant.new(tenant_params)
    authorize @tenant

    if @tenant.save
      redirect_to @tenant, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    @tenant = Tenant.find(params[:id])
    authorize @tenant
    if @tenant.update(tenant_params)
      redirect_to @tenant, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @tenant = Tenant.find(params[:id])
    authorize @tenant
    @tenant.destroy
    redirect_to tenants_url, notice: t(".success")
  end

  private

  def tenant_params
    params.expect(tenant: %i[name email phone_number])
  end
end
