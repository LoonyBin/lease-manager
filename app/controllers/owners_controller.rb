# frozen_string_literal: true

class OwnersController < ApplicationController
  before_action :set_owner, only: %i[show edit update destroy]

  def index
    @owners = Owner.order(:name)
  end

  def show
    @properties = @owner.properties.includes(:leases)
  end

  def new
    @owner = Owner.new
  end

  def edit; end

  def create
    @owner = Owner.new(owner_params)

    if @owner.save
      redirect_to @owner, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @owner.update(owner_params)
      redirect_to @owner, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @owner.destroy
    redirect_to owners_url, notice: t(".success")
  end

  private

  def set_owner
    @owner = Owner.find(params[:id])
  end

  def owner_params
    params.expect(owner: %i[name address])
  end
end
