# frozen_string_literal: true

class TenantsController < ApplicationController
  def index
    @tenants = Tenant.all
  end

  def show
    @tenant = Tenant.find(params[:id])
  end

  def new
    @tenant = Tenant.new
  end

  def edit
    @tenant = Tenant.find(params[:id])
  end

  def create
    @tenant = Tenant.new(tenant_params)

    if @tenant.save
      redirect_to @tenant, notice: "Tenant was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    @tenant = Tenant.find(params[:id])
    if @tenant.update(tenant_params)
      redirect_to @tenant, notice: "Tenant was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @tenant = Tenant.find(params[:id])
    @tenant.destroy
    redirect_to tenants_url, notice: "Tenant was successfully destroyed."
  end

  private

  def tenant_params
    params.expect(tenant: %i[name email phone_number])
  end
end
