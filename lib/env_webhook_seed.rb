# frozen_string_literal: true

# Registers the deployment's inbound webhook receiver, read from
# `DOCUSEAL_WEBHOOK_URL` / `DOCUSEAL_WEBHOOK_EVENTS`, on every Account.
#
# Deployment-agnostic on purpose: the URL — including whatever query-string
# credential the receiver authenticates with — comes from the environment, so
# this file knows nothing about who is running it.
#
# Why every account and not just the first: an embedding app provisions one
# Account per tenant through Api::Internal::ProvisionAccountsController, and
# `WebhookUrls.for_account_id` only looks at the submitter's own account (plus
# explicitly linked ones). Seeding a single account therefore leaves every other
# tenant with no callback at all — submitters complete their forms and the
# embedding app is never told, so the document stays unsigned on its side.
module EnvWebhookSeed
  DEFAULT_EVENTS = 'form.completed,template.created'

  module_function

  # Upsert the configured callback onto one account. Idempotent: re-running
  # rewrites the events of the existing row rather than adding a second one,
  # and a rotated credential in the query string updates the same row instead
  # of leaving a stale duplicate behind to deliver rejected callbacks.
  def call(account)
    url = configured_url
    return if url.blank?

    row = find_by_endpoint(account, url) || account.webhook_urls.new

    row.url = url
    row.events = configured_events
    row.save!

    row
  end

  def call_all
    return if configured_url.blank?

    Account.find_each { |account| call(account) }
  end

  def configured_url
    ENV['DOCUSEAL_WEBHOOK_URL'].to_s.strip
  end

  def configured_events
    ENV.fetch('DOCUSEAL_WEBHOOK_EVENTS', DEFAULT_EVENTS)
       .split(',').map(&:strip).reject(&:empty?)
  end

  # `url` is encrypted at rest, so the match has to happen in Ruby. Accounts
  # hold a handful of webhook rows at most, so loading them is cheap.
  def find_by_endpoint(account, url)
    endpoint = url.split('?').first

    account.webhook_urls.detect { |row| row.url.to_s.split('?').first == endpoint }
  end
end
