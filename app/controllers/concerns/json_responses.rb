# frozen_string_literal: true

# JSON counterparts to the standard HTML responses, so API tokens can drive
# the same RESTful controllers. Each helper takes the HTML behavior as the
# caller's block (or the default template render), keeping browser flows
# exactly as they were while JSON gets the record, its errors, or nothing.
module JsonResponses
  extend ActiveSupport::Concern

  private

  # GET actions: default HTML template, or the payload serialized as JSON.
  def respond_ok(payload)
    respond_to do |format|
      format.html
      format.json { render json: payload }
    end
  end

  def respond_created(record, &)
    respond_saved(record, :created, &)
  end

  def respond_updated(record, &)
    respond_saved(record, :ok, &)
  end

  def respond_invalid(record, &)
    respond_to do |format|
      format.html(&)
      format.json { render json: { errors: record.errors }, status: :unprocessable_content }
    end
  end

  def respond_destroyed(&)
    respond_to do |format|
      format.html(&)
      format.json { head :no_content }
    end
  end

  def respond_saved(record, status, &)
    respond_to do |format|
      format.html(&)
      format.json { render json: record, status: status }
    end
  end
end
