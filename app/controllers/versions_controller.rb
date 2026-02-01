# frozen_string_literal: true

class VersionsController < ApplicationController
  layout "settings"

  def index # rubocop:disable Metrics/AbcSize
    @versions = policy_scope(Version, policy_scope_class: VersionPolicy::Scope)
    @versions = @versions.where(item_type: params[:item_type]) if params[:item_type].present?
    @versions = @versions.where(item_id: params[:item_id]) if params[:item_id].present?
    @q = @versions.ransack(params[:q])
    @q.sorts = "created_at desc" if @q.sorts.empty?
    @versions = @q.result.page(params[:page]).per(20)
  end

  def show
    @version = Version.find(params[:id])
    authorize @version, policy_class: VersionPolicy
  end

  def destroy
    @version = Version.find(params[:id])
    authorize @version, policy_class: VersionPolicy
    @version.destroy
    redirect_to versions_path, notice: t(".success")
  end
end
