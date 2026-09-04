# frozen_string_literal: true

require 'rails_helper'
require 'erb'
require 'yaml'

# Guards the GCS URL-signing config. On GCE the container authenticates via the
# metadata server (no private key), so ActiveStorage must sign URLs through the
# IAM SignBlob API (`iam: true` + `gsa_email`). Without it, `signed_url` raises
# Google::Cloud::Storage::SignedUrlUnavailable and every preview-image URL 500s.
RSpec.describe 'config/storage.yml google service' do
  def render_google(env_overrides)
    original = ENV.to_hash
    env_overrides.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yaml = ERB.new(Rails.root.join('config/storage.yml').read).result
    YAML.safe_load(yaml, aliases: true)['google']
  ensure
    ENV.replace(original)
  end

  context 'when GCS_GSA_EMAIL is set (GCE metadata auth, no key file)' do
    it 'signs URLs via IAM with that email as the issuer' do
      google = render_google('GCS_CREDENTIALS' => nil, 'GCS_GSA_EMAIL' => 'runtime@x.iam.gserviceaccount.com',
                             'GCS_PROJECT' => 'proj', 'GCS_BUCKET' => 'bucket')

      expect(google['iam']).to be(true)
      expect(google['gsa_email']).to eq('runtime@x.iam.gserviceaccount.com')
      expect(google).not_to have_key('credentials')
    end
  end

  context 'when neither a key nor GCS_GSA_EMAIL is provided' do
    it 'stays generic — no IAM signing, no hardcoded issuer' do
      google = render_google('GCS_CREDENTIALS' => nil, 'GCS_GSA_EMAIL' => nil,
                             'GCS_PROJECT' => 'proj', 'GCS_BUCKET' => 'bucket')

      expect(google).not_to have_key('iam')
      expect(google).not_to have_key('gsa_email')
      expect(google).not_to have_key('credentials')
    end
  end

  context 'when an explicit GCS_CREDENTIALS key is provided' do
    it 'uses the key and does not enable IAM signing' do
      google = render_google('GCS_CREDENTIALS' => '/etc/docuseal/gcs-key.json',
                             'GCS_PROJECT' => 'proj', 'GCS_BUCKET' => 'bucket')

      expect(google['credentials']).to eq('/etc/docuseal/gcs-key.json')
      expect(google).not_to have_key('iam')
    end
  end
end
