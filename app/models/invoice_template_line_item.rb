# frozen_string_literal: true

class InvoiceTemplateLineItem < ApplicationRecord
  belongs_to :invoice_template, touch: true

  validates :name, presence: true
  validates :amount_expression, presence: true
  validates :category, presence: true
  validates :tax_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validate :amount_expression_references_known_variables
  validate :name_placeholders_are_known

  private

  def amount_expression_references_known_variables
    return if amount_expression.blank?

    unknown = InvoiceTemplates::AmountEvaluator.unknown_identifiers(amount_expression)
    errors.add(:amount_expression, "references unknown variables: #{unknown.join(', ')}") if unknown.any?
  rescue InvoiceTemplates::EvaluationError
    errors.add(:amount_expression, "is not a valid expression")
  end

  def name_placeholders_are_known
    return if name.blank?

    unknown = InvoiceTemplates::TextRenderer.unknown_placeholders(name)
    errors.add(:name, "references unknown placeholders: #{unknown.join(', ')}") if unknown.any?
  end
end
