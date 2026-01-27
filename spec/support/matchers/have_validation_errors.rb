# frozen_string_literal: true

RSpec::Matchers.define :have_validation_error do |field|
  match do |actual|
    @errors = actual.errors[field]

    if @expected_message
      @errors.include?(@expected_message)
    else
      @errors.any?
    end
  end

  chain :with_message do |message|
    @expected_message = message
  end

  failure_message do |actual|
    "expected #{actual} to have validation error on :#{field}#{with_message_text}, " \
      "but got #{@errors.empty? ? 'none' : @errors}"
  end

  failure_message_when_negated do |actual|
    "expected #{actual} NOT to have validation error on :#{field}#{with_message_text}, but got #{@errors}"
  end

  def with_message_text
    @expected_message ? " with message #{@expected_message.inspect}" : ""
  end
end
