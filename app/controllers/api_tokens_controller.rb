# frozen_string_literal: true

class ApiTokensController < ApplicationController
  def create
    @api_token = current_user.api_tokens.new(api_token_params)
    authorize @api_token

    if @api_token.save
      # One-time exposure: the plaintext lives in the flash for a single render.
      flash[:new_api_token] = @api_token.plaintext_token
      redirect_to profile, notice: t(".success")
    else
      redirect_to profile, alert: creation_alert
    end
  end

  def destroy
    @api_token = current_user.api_tokens.find(params.expect(:id))
    authorize @api_token
    @api_token.revoke!
    redirect_to profile, notice: t(".success")
  end

  private

  # The token UI lives on the creator's own profile page.
  def profile
    user_path(current_user)
  end

  def creation_alert
    @api_token.errors.full_messages.to_sentence
  end

  def api_token_params
    params.expect(api_token: %i[name expires_at scope])
  end
end
