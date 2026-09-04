# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnvWebhookSeed do
  let(:url) { 'https://app.example.com/webhooks/docuseal?token=s3cret' }

  before { allow(ENV).to receive(:[]).and_call_original }

  def stub_env(webhook_url: url, events: nil)
    allow(ENV).to receive(:[]).with('DOCUSEAL_WEBHOOK_URL').and_return(webhook_url)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch)
      .with('DOCUSEAL_WEBHOOK_EVENTS', anything)
      .and_return(events || 'form.completed,template.created')
  end

  describe '.call' do
    let(:account) { create(:account) }

    it 'registers the env callback on the account' do
      stub_env

      expect { described_class.call(account) }.to change { account.webhook_urls.count }.from(0).to(1)

      webhook = account.webhook_urls.last

      expect(webhook.url).to eq(url)
      expect(webhook.events).to include('form.completed')
    end

    it 'is idempotent across boots' do
      stub_env
      described_class.call(account)

      expect { described_class.call(account) }.not_to(change { account.webhook_urls.count })
    end

    it 'updates the event list when the env changes' do
      stub_env
      described_class.call(account)

      stub_env(events: 'form.completed')

      expect { described_class.call(account) }
        .to change { account.webhook_urls.last.reload.events }.to(%w[form.completed])
    end

    # The URL carries the `?token=` the receiving app authenticates with. An
    # unset secret renders an empty URL, and registering that would queue a
    # callback that can only ever be rejected.
    it 'registers nothing when the env is unset' do
      stub_env(webhook_url: nil)

      expect { described_class.call(account) }.not_to(change(WebhookUrl, :count))
    end

    it 'registers nothing when the env is blank' do
      stub_env(webhook_url: '   ')

      expect { described_class.call(account) }.not_to(change(WebhookUrl, :count))
    end
  end

  describe '.call_all' do
    # Accounts are provisioned per tenant (Api::Internal::ProvisionAccountsController),
    # so seeding only `Account.first` left every clinic but one with no callback:
    # patients signed, the app was never told, and the document stayed "unsigned".
    it 'registers the callback on every account, not just the first' do
      accounts = create_list(:account, 3)
      stub_env

      described_class.call_all

      expect(accounts.map { |a| a.webhook_urls.count }).to eq([1, 1, 1])
    end
  end
end
