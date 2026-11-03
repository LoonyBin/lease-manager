# frozen_string_literal: true

class ReminderStepsController < ApplicationController
  before_action :set_lease

  def new
    @reminder_step = @lease.reminder_steps.build(position: next_position)
    authorize @reminder_step
    set_form_collections
  end

  def edit
    @reminder_step = @lease.reminder_steps.find(params.expect(:id))
    authorize @reminder_step
    set_form_collections
  end

  def create
    @reminder_step = @lease.reminder_steps.build(reminder_step_params)
    authorize @reminder_step
    if @reminder_step.save
      respond_created(@reminder_step) { redirect_to @lease, notice: t(".success") }
    else
      set_form_collections
      respond_invalid(@reminder_step) { render :new, status: :unprocessable_content }
    end
  end

  def update
    @reminder_step = @lease.reminder_steps.find(params.expect(:id))
    authorize @reminder_step
    if @reminder_step.update(reminder_step_params)
      respond_updated(@reminder_step) { redirect_to @lease, notice: t(".success") }
    else
      set_form_collections
      respond_invalid(@reminder_step) { render :edit, status: :unprocessable_content }
    end
  end

  def destroy
    @reminder_step = @lease.reminder_steps.find(params.expect(:id))
    authorize @reminder_step
    @reminder_step.destroy
    respond_destroyed { redirect_to @lease, notice: t(".success") }
  end

  private

  def set_lease
    @lease = Lease.find(params.expect(:lease_id))
  end

  def next_position
    (@lease.reminder_steps.maximum(:position) || 0) + 1
  end

  # Addresses already known for the lease, offered as autocomplete only —
  # any address can be typed, recipients need no user account.
  def set_form_collections
    tenant_emails = [@lease.tenant&.email] + user_emails_for(@lease.tenant)
    owner_emails = user_emails_for(@lease.property&.owner)
    @suggested_emails = (tenant_emails + owner_emails).compact_blank.map { |e| e.strip.downcase }.uniq.sort
  end

  def user_emails_for(associable)
    return [] if associable.nil?

    associable.users.pluck(:email)
  end

  def reminder_step_params
    params.expect(reminder_step: %i[position offset_days repeat_every_days subject body to_emails])
  end
end
