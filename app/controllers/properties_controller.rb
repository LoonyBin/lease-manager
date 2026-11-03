# frozen_string_literal: true

class PropertiesController < ApplicationController
  def index
    @q = policy_scope(Property).ransack(params[:q])
    @properties = @q.result.page(params[:page]).per(20)
    respond_ok @properties
  end

  def show
    @property = Property.find(params.expect(:id))
    authorize @property
    respond_ok @property
  end

  def new
    @property = Property.new
    authorize @property
  end

  def edit
    @property = Property.find(params.expect(:id))
    authorize @property
  end

  def create
    @property = Property.new(property_params)
    authorize @property

    if @property.save
      respond_created(@property) { redirect_to @property, notice: t(".success") }
    else
      respond_invalid(@property) { render :new, status: :unprocessable_content }
    end
  end

  def update
    @property = Property.find(params.expect(:id))
    authorize @property
    if @property.update(property_params)
      respond_updated(@property) { redirect_to @property, notice: t(".success") }
    else
      respond_invalid(@property) { render :edit, status: :unprocessable_content }
    end
  end

  def destroy
    @property = Property.find(params.expect(:id))
    authorize @property
    @property.destroy
    respond_destroyed { redirect_to properties_url, notice: t(".success") }
  end

  private

  def property_params
    params.expect(property: %i[name address owner_id capacity unit])
  end
end
