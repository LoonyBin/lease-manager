# frozen_string_literal: true

class UserAssociationsController < ApplicationController
  def create
    @user_association = UserAssociation.new(user_association_params)
    authorize @user_association

    if @user_association.save
      redirect_to redirect_target, notice: t(".success")
    else
      redirect_to redirect_target, alert: @user_association.errors.full_messages.to_sentence
    end
  end

  def destroy
    @user_association = UserAssociation.find(params[:id])
    authorize @user_association
    @user_association.destroy
    redirect_back_or_to(root_path, notice: t(".success"))
  end

  private

  def user_association_params
    params.expect(user_association: %i[user_id associable_type associable_id])
  end

  def redirect_target
    @user_association.associable || @user_association.user
  end
end
