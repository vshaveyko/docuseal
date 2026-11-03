# frozen_string_literal: true

describe 'Templates detect fields API' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }
  let(:detected) do
    [{ uuid: SecureRandom.uuid, type: 'checkbox', required: false, preferences: {},
       areas: [{ x: 0.1, y: 0.2, w: 0.02, h: 0.02, page: 0, attachment_uuid: template.schema_documents.first.uuid }] }]
  end

  describe 'POST /api/templates/:template_id/detect_fields' do
    it "answers the fields detected on the template's documents without saving them" do
      allow(Templates::DetectFields).to receive(:call).and_return([detected, nil])

      expect do
        post "/api/templates/#{template.id}/detect_fields", headers: { 'x-auth-token': author.access_token.token }
      end.not_to(change { template.reload.fields })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['fields']).to eq(JSON.parse(detected.to_json) * template.schema_documents.size)
      expect(Templates::DetectFields).to have_received(:call)
        .with(an_instance_of(StringIO), attachment: template.schema_documents.first)
    end

    it "refuses another account's template" do
      other = create(:user, account: create(:account))

      post "/api/templates/#{template.id}/detect_fields", headers: { 'x-auth-token': other.access_token.token }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
