# frozen_string_literal: true

require "rails_helper"

# Dependency guard for issue #183: image_processing 2.0 made ruby-vips a soft
# dependency, which silently disabled Active Storage image analysis and variant
# generation. Without the ruby-vips gem *and* the libvips system library,
# ActiveStorage::Analyzer::ImageAnalyzer::Vips returns {} (no width/height) and
# blob.variant(...).processed raises LoadError, so these examples fail. Variant
# generation is the latent trap #183 exists to close, so it is guarded here too.
RSpec.describe ActiveStorage::Blob do
  let(:blob) do
    Rails.root.join("spec/fixtures/files/sample.png").open do |io|
      described_class.create_and_upload!(io: io, filename: "sample.png", content_type: "image/png")
    end
  end

  it "extracts width and height metadata from an image via ruby-vips" do
    blob.analyze

    # sample.png is 1x1; assert the exact dimensions so a garbage-dimension
    # result can't pass on key presence alone.
    expect(blob.reload.metadata).to include("width" => 1, "height" => 1)
  end

  it "processes an image variant via ruby-vips" do
    variant = blob.variant(resize_to_limit: [100, 100]).processed

    expect(variant.image).to be_attached
  end
end
