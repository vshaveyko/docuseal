# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Templates::ProcessDocument do
  describe '.build_and_upload_blob' do
    # Regression: the PNG branch referenced an undefined local `page` — a
    # leftover from renaming the method parameter to `image`. Every other
    # reference in the method was updated; this one was missed, so the branch
    # raised `NameError`, failed the render promise, and 500-ed every
    # "drag a PDF into the builder" upload (default format is `.png`).
    it 'renders a PNG page blob from the image without raising' do
      image = Vips::Image.black(64, 64, bands: 4)

      blob = described_class.build_and_upload_blob(image, 0)

      expect(blob).to be_a(ActiveStorage::Blob)
      expect(blob.filename.to_s).to eq('0.png')
    end
  end
end
