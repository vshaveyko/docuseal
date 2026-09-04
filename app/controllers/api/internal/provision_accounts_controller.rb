# frozen_string_literal: true

module Api
  module Internal
    # Server-to-server endpoint the parent EHR app calls to provision a DocuSeal
    # Account + owner User + access token for a tenant. Idempotent by owner email.
    #
    # Auth is the HMAC `X-Provision-Token` (see ProvisionToken), NOT an API access
    # token — so this controller skips Devise auth, CanCan, and CSRF entirely.
    class ProvisionAccountsController < ActionController::API
      include ActiveStorage::SetCurrent

      wrap_parameters false

      before_action :authenticate_provision_token!

      def create
        user = User.find_by(email: @payload['email'])

        user ||= ApplicationRecord.transaction { provision_account_and_owner!(@payload) }

        render json: {
          email: user.email,
          access_token: user.access_token.token,
          account_uuid: user.account.uuid
        }
      end

      private

      def provision_account_and_owner!(payload)
        account = Account.create!(
          name: payload['name'].presence || 'EHR Account',
          timezone: 'UTC',
          locale: 'en-US'
        )

        Rails.logger.info("[provision_account] est=#{payload['est'].inspect} account_uuid=#{account.uuid}")

        # Give the tenant its callback now rather than at the next boot's
        # env-seed pass: submitters can complete a form minutes after the
        # account is created, and `WebhookUrls.for_account_id` only consults the
        # submitter's own account — no callback row means the completion is
        # never reported and the embedding app keeps the document unsigned.
        EnvWebhookSeed.call(account)

        account.users.create!(
          email: payload['email'],
          first_name: 'EHR',
          last_name: 'Owner',
          role: User::ADMIN_ROLE,
          password: SecureRandom.hex(16)
        )
      end

      def authenticate_provision_token!
        @payload = ProvisionToken.verify(request.headers['X-Provision-Token'].to_s)

        render(json: { error: 'unauthorized' }, status: :unauthorized) if @payload.blank?
      end
    end
  end
end
