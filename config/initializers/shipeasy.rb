# frozen_string_literal: true

# Shipeasy SDK: error reporting (see()), feature flags, and i18n helpers.
# The SDK auto-mounts RackMiddleware (anonymous bucketing cookie) and the
# i18n view helpers when loaded inside Rails.
#
# SHIPEASY_SERVER_KEY is required in production; dev/test warn and skip so
# engineers can boot without a live Shipeasy account.
require 'shipeasy-sdk'

Rails.application.config.after_initialize do
  server_key = ENV.fetch('SHIPEASY_SERVER_KEY', nil)
  client_key = ENV.fetch('SHIPEASY_CLIENT_KEY', nil)

  if server_key.present?
    Shipeasy.configure do |c|
      c.api_key = server_key
      c.public_key = client_key if client_key.present?
      c.profile = 'default'
    end
  elsif Rails.env.production?
    raise 'SHIPEASY_SERVER_KEY is missing. Set it in ENV or docuseal/.env.'
  else
    Rails.logger.warn('[Shipeasy] SDK not configured — set SHIPEASY_SERVER_KEY to enable error reporting and flags.')
  end
end
