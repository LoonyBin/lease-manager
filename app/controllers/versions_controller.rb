# frozen_string_literal: true

class VersionsController < ApplicationController
  def index
    @versions = policy_scope(Version, policy_scope_class: VersionPolicy::Scope)
    @q = @versions.ransack(params[:q])
    @q.sorts = "created_at desc" if @q.sorts.empty?
    @versions = @q.result.page(params[:page]).per(20)
  end

  def show
    @version = Version.find(params.expect(:id))
    authorize @version, policy_class: VersionPolicy
  end

  def destroy
    @version = Version.find(params.expect(:id))
    authorize @version, policy_class: VersionPolicy
    @version.destroy
    redirect_to versions_path, notice: t(".success")
  end
end
