# frozen_string_literal: true

class ApiTokensController < ApplicationController
  # Token management is browser-session only: no API token can ever reach this
  # controller (ApplicationController#enforce_token_permissions early-exits on
  # it). These actions are therefore always session-authenticated.
  def create
    @api_token = current_user.api_tokens.new(create_attributes)
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

  # Presets are resolved server-side — the source of truth — so a submitted
  # preset expands to its registry set regardless of the checkbox state the
  # client sent. A "custom" (or unknown) preset is normalised to nil, and the
  # submitted checkboxes are sanitised: the hidden-field blank sentinel is
  # dropped and only registry-grantable entries survive the intersection.
  def create_attributes
    attrs = token_params
    preset = attrs[:preset].presence
    preset = nil unless ApiToken::PRESETS.include?(preset)

    { name: attrs[:name],
      expires_at: attrs[:expires_at],
      preset: preset,
      permissions: permissions_for(preset, attrs[:permissions]) }
  end

  def permissions_for(preset, submitted)
    case preset
    when "read_only" then ApiToken::PermissionRegistry.read_preset
    when "full" then ApiToken::PermissionRegistry.full_preset
    else Array(submitted).compact_blank & ApiToken::PermissionRegistry.grantable_actions
    end
  end

  def token_params
    params.permit(api_token: [:name, :expires_at, :preset, { permissions: [] }])
          .fetch(:api_token, ActionController::Parameters.new)
  end
end
