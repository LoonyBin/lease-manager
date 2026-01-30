# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def create
    user = User.from_omniauth(request.env["omniauth.auth"])
    session[:user_id] = user.id
    redirect_to root_path, notice: t(".success")
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: t(".success")
  end
end
