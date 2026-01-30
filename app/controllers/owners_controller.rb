# frozen_string_literal: true

class OwnersController < ApplicationController
  def index
    @owners = policy_scope(Owner).order(:name)
  end

  def show
    @owner = Owner.find(params[:id])
    authorize @owner
    @properties = @owner.properties.includes(:leases)
  end

  def new
    @owner = Owner.new
    authorize @owner
  end

  def edit
    @owner = Owner.find(params[:id])
    authorize @owner
  end

  def create
    @owner = Owner.new(owner_params)
    authorize @owner

    if @owner.save
      redirect_to @owner, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    @owner = Owner.find(params[:id])
    authorize @owner
    if @owner.update(owner_params)
      redirect_to @owner, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @owner = Owner.find(params[:id])
    authorize @owner
    @owner.destroy
    redirect_to owners_url, notice: t(".success")
  end

  private

  def owner_params
    params.expect(owner: %i[name address])
  end
end
