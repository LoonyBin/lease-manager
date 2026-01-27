# frozen_string_literal: true

class PropertiesController < ApplicationController
  def index
    @properties = Property.all
  end

  def show
    @property = Property.find(params[:id])
  end

  def new
    @property = Property.new
  end

  def edit
    @property = Property.find(params[:id])
  end

  def create
    @property = Property.new(property_params)

    if @property.save
      redirect_to @property, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    @property = Property.find(params[:id])
    if @property.update(property_params)
      redirect_to @property, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @property = Property.find(params[:id])
    @property.destroy
    redirect_to properties_url, notice: t(".success")
  end

  private

  def property_params
    params.expect(property: %i[name address])
  end
end
