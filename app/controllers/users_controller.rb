# frozen_string_literal: true

class UsersController < ApplicationController
  def index
    @q = policy_scope(User).ransack(params[:q])
    @users = @q.result.page(params[:page]).per(20)
  end

  def show
    @user = User.find(params.expect(:id))
    authorize @user
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
      redirect_to @user, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    @user = User.find(params.expect(:id))
    authorize @user
    if @user.update(user_params)
      redirect_to @user, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @user = User.find(params.expect(:id))
    authorize @user
    @user.destroy
    redirect_to users_url, notice: t(".success")
  end

  private

  def user_params
    params.expect(user: %i[uid provider email name role])
  end
end
