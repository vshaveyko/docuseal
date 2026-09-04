# frozen_string_literal: true

require 'rails_helper'

# Exercises the FULL "drag a PDF into the builder" pipeline against the real
# sample PDF (pdfium rasterization + vips preview generation), which the
# unit spec on build_and_upload_blob does not cover. Reproduces the prod
# `/templates/:id/documents` 500 end to end.
RSpec.describe Templates::CreateAttachments do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }

  let(:uploaded_file) do
    ActionDispatch::Http::UploadedFile.new(
      tempfile: Rails.root.join('spec/fixtures/sample-document.pdf').open,
      filename: 'sample-document.pdf',
      type: 'application/pdf'
    )
  end

  it 'processes an uploaded PDF into a document with preview images' do
    documents, = described_class.call(template, { files: [uploaded_file] }, extract_fields: true)

    expect(documents.size).to eq(1)
    document = documents.first
    expect(document.preview_images.attached?).to be(true)
    expect(document.preview_images.count).to be >= 1
  end
end
