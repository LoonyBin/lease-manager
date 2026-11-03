# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReminderMailer do
  describe "#reminder" do
    subject(:mail) { described_class.reminder(notification) }

    let(:notification) do
      create(:invoice_notification, recipient_email: "chaser@example.com",
                                    subject: "Invoice 2026-004 is due today",
                                    body: "Hello Alice,\n\n1,180 is outstanding.")
    end

    it "addresses the notification's recipient" do
      expect(mail.to).to eq(["chaser@example.com"])
    end

    it "uses the snapshot subject" do
      expect(mail.subject).to eq("Invoice 2026-004 is due today")
    end

    it "sends the snapshot body" do
      expect(mail.body.to_s).to include("Hello Alice,", "1,180 is outstanding.")
    end

    it "sends from the configured address" do
      expect(mail.from).to eq([ENV.fetch("MAIL_FROM", "no-reply@example.com")])
    end
  end
end
