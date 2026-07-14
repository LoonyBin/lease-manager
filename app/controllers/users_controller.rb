# frozen_string_literal: true

class UsersController < ApplicationController
  def index
    @q = policy_scope(User).ransack(params[:q])
    @users = @q.result.page(params[:page]).per(20)
    respond_ok @users
  end

  def show
    @user = User.find(params.expect(:id))
    authorize @user
    respond_ok @user
  end

  def new
    @user = User.new
    authorize @user
  end

  def edit
    @user = User.find(params.expect(:id))
    authorize @user
  end

  def create
    @user = User.new(user_params)
    authorize @user

    if @user.save
      respond_created(@user) { redirect_to @user, notice: t(".success") }
    else
      respond_invalid(@user) { render :new, status: :unprocessable_content }
    end
  end

  def update
    @user = User.find(params.expect(:id))
    authorize @user
    if @user.update(user_params)
      respond_updated(@user) { redirect_to @user, notice: t(".success") }
    else
      respond_invalid(@user) { render :edit, status: :unprocessable_content }
    end
  end

  def destroy
    @user = User.find(params.expect(:id))
    authorize @user
    @user.destroy
    respond_destroyed { redirect_to users_url, notice: t(".success") }
  end

  private

  def user_params
    params.expect(user: %i[uid provider email name role])
  end
end
