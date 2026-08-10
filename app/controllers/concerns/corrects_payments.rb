# frozen_string_literal: true

# The correction half of PaymentsController#update: everything that turns an
# edit into a re-inference, kept out of the controller body so the status
# transition path stays the whole of the controller's own update logic. See #193.
module CorrectsPayments
  extend ActiveSupport::Concern

  private

  def correct_payment
    authorize_destination_lease!
    warnings = Payments::Correction.call(@payment, correction_params).warnings
    respond_correction(warnings)
  rescue ActiveRecord::RecordInvalid
    @leases = edit_leases
    respond_invalid(@payment) { render :edit, status: :unprocessable_content }
  end

  # Non-blocking warnings: machine-readable in the JSON body, a flash in HTML.
  def respond_correction(warnings)
    respond_to do |format|
      format.html do
        flash[:warning] = warnings.pluck(:message) if warnings.any?
        redirect_to @payment, notice: t("payments.update.success")
      end
      format.json { render json: @payment.as_json.merge("warnings" => warnings), status: :ok }
    end
  end

  # A client that sends +status+ alongside an editable field is confused about
  # the contract; refuse it rather than silently drop +status+, which would let
  # an edit self-confirm a draft outside payment_status_for_user's rules.
  def reject_mixed_payload
    @payment.errors.add(:base, t("payments.correction.status_not_editable"))
    @leases = edit_leases
    respond_invalid(@payment) { render :edit, status: :unprocessable_content }
  end

  # Cross-*tenant* moves are a business decision the system may not veto (warn,
  # not block). Moving onto a lease the user cannot even see is a *security*
  # boundary and stays Pundit's job. Admins pass show? unconditionally.
  def authorize_destination_lease!
    new_lease_id = correction_params[:lease_id]
    return if new_lease_id.blank? || new_lease_id.to_i == @payment.lease_id

    authorize Lease.find(new_lease_id), :show?
  end

  # Correcting a payment may re-home it onto an archived or terminated lease, so
  # the edit form offers the full authorized set, not new's active/outstanding filter.
  def edit_leases
    policy_scope(Lease).includes(:property, :tenant)
  end

  def correction_params
    params.expect(payment: %i[lease_id date amount mode reference_number payment_type attachment])
  end
end
