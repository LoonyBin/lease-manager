# frozen_string_literal: true

class InvoiceTemplatesController < ApplicationController
  before_action :set_lease

  def new
    @invoice_template = @lease.invoice_templates.build
    @invoice_template.line_items.build
    authorize @invoice_template
  end

  def edit
    @invoice_template = @lease.invoice_templates.find(params.expect(:id))
    authorize @invoice_template
  end

  def create
    @invoice_template = @lease.invoice_templates.build(invoice_template_params)
    authorize @invoice_template
    if @invoice_template.save
      redirect_to @lease, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    @invoice_template = @lease.invoice_templates.find(params.expect(:id))
    authorize @invoice_template
    if @invoice_template.update(invoice_template_params)
      redirect_to @lease, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @invoice_template = @lease.invoice_templates.find(params.expect(:id))
    authorize @invoice_template
    @invoice_template.destroy
    redirect_to @lease, notice: t(".success")
  end

  # Renders the template form with the invoice that would be generated for
  # the requested month, without saving anything.
  def preview
    @invoice_template = find_or_build_template
    authorize @invoice_template, @invoice_template.persisted? ? :update? : :create?
    build_preview
    render @invoice_template.persisted? ? :edit : :new
  end

  private

  def set_lease
    @lease = Lease.find(params.expect(:lease_id))
  end

  def find_or_build_template
    if params[:id].present?
      @lease.invoice_templates.find(params.expect(:id)).tap { |t| t.assign_attributes(invoice_template_params) }
    else
      @lease.invoice_templates.build(invoice_template_params)
    end
  end

  def build_preview
    @preview_month = parse_preview_month
    return unless @invoice_template.valid?

    invoice = TemplateInvoiceGenerator.new(@invoice_template, @preview_month, find_existing: false).call
    if invoice
      @preview_invoice = invoice
    else
      @preview_message = t("invoice_templates.preview.outside_window")
    end
  rescue InvoiceTemplates::EvaluationError => e
    @preview_error = t("invoice_templates.preview.evaluation_error", message: e.message)
  end

  def parse_preview_month
    date = begin
      Date.parse(params[:preview_month].to_s)
    rescue ArgumentError, TypeError
      Date.current
    end
    date.beginning_of_month
  end

  def invoice_template_params
    params.expect(invoice_template: [:name, :payment_due_in, :starts_on, :ends_on,
                                     { line_items_attributes: [%i[id name amount_expression tax_rate
                                                                  category _destroy]] }])
  end
end
