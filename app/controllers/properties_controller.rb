# frozen_string_literal: true

class PropertiesController < ApplicationController
  def index
    @q = policy_scope(Property).ransack(params[:q])
    @properties = @q.result.page(params[:page]).per(20)
  end

  def show
    @property = Property.find(params[:id])
    authorize @property
  end

  def new
    @property = Property.new
    authorize @property
  end

  def edit
    @property = Property.find(params[:id])
    authorize @property
  end

  def create
    @property = Property.new(property_params)
    authorize @property

    if @property.save
      redirect_to @property, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    @property = Property.find(params[:id])
    authorize @property
    if @property.update(property_params)
      redirect_to @property, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @property = Property.find(params[:id])
    authorize @property
    @property.destroy
    redirect_to properties_url, notice: t(".success")
  end

  private

  def property_params
    params.expect(property: %i[name address owner_id capacity unit])
  end
end
