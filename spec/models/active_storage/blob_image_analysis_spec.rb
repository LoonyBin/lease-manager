# frozen_string_literal: true

require "rails_helper"

# Dependency guard for issue #183: image_processing 2.0 made ruby-vips a soft
# dependency, which silently disabled Active Storage image analysis (and variant
# generation). Without the ruby-vips gem *and* the libvips system library,
# ActiveStorage::Analyzer::ImageAnalyzer::Vips returns {} and no width/height is
# recorded, so this example fails.
RSpec.describe ActiveStorage::Blob do
  let(:blob) do
    described_class.create_and_upload!(
      io: Rails.root.join("spec/fixtures/files/sample.png").open,
      filename: "sample.png",
      content_type: "image/png"
    )
  end

  it "extracts width and height metadata from an image via ruby-vips" do
    blob.analyze

    expect(blob.reload.metadata).to include("width", "height")
  end
end
