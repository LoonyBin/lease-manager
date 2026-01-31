# frozen_string_literal: true

class VersionsController < ApplicationController
  def index
    @versions = policy_scope(PaperTrail::Version, policy_scope_class: VersionPolicy::Scope).order(created_at: :desc)
  end

  def show
    @version = PaperTrail::Version.find(params[:id])
    authorize @version, policy_class: VersionPolicy
  end

  def destroy
    @version = PaperTrail::Version.find(params[:id])
    authorize @version, policy_class: VersionPolicy
    @version.destroy
    redirect_to versions_path, notice: t(".success")
  end
end
