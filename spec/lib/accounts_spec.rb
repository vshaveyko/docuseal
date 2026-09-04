# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accounts do
  describe '.load_signing_pkcs' do
    let(:account) { create(:account) }

    before { allow(Docuseal).to receive(:multitenant?).and_return(false) }

    context 'when the deployment has no signing certificate at all' do
      # The chain is created once, by the /setup wizard. A deployment that
      # provisions its accounts another way — or one restored onto a fresh
      # database — has no row, and the fallback called `.value` on that nil, so
      # EVERY completed submission died generating its signed PDF with
      # `NoMethodError: undefined method 'value' for nil`.
      it 'generates and persists one instead of raising' do
        expect(EncryptedConfig.where(key: EncryptedConfig::ESIGN_CERTS_KEY)).to be_empty

        expect { described_class.load_signing_pkcs(account) }
          .to change { EncryptedConfig.where(key: EncryptedConfig::ESIGN_CERTS_KEY).count }.from(0).to(1)
      end

      it 'returns a usable pkcs12 for signing' do
        expect(described_class.load_signing_pkcs(account)).to be_a(OpenSSL::PKCS12)
      end

      it 'reuses the generated chain on the next call' do
        described_class.load_signing_pkcs(account)

        expect { described_class.load_signing_pkcs(account) }
          .not_to(change { EncryptedConfig.where(key: EncryptedConfig::ESIGN_CERTS_KEY).count })
      end
    end

    context 'when another account already has a chain' do
      let(:other_account) { create(:account) }

      it 'falls back to it rather than generating a second one' do
        described_class.load_signing_pkcs(other_account)

        expect { described_class.load_signing_pkcs(account) }
          .not_to(change { EncryptedConfig.where(key: EncryptedConfig::ESIGN_CERTS_KEY).count })
      end
    end
  end
end
