require 'json'
require 'uri'

module DaVinciCRDTestKit
  # The CRD server authorizes a workspace bearer. The machine key stays in
  # this process and is exchanged at POST {origin}/auth/token. The origin is
  # the app, not a prefix copied from the service path. The key is not a
  # suite input: Inferno stores those.
  class AnteriorWorkspaceToken
    MACHINE_KEY_ENV = 'CRD_SERVER_MACHINE_KEY'.freeze
    CLIENT_ID = 'inferno'.freeze

    class MissingKey < StandardError
    end

    class << self
      def authorization_header(service_url)
        "Bearer #{bearer(service_url)}"
      end

      def reset!
        mutex.synchronize { @cache = {} }
      end

      private

      def bearer(service_url)
        url = token_url(service_url)
        mutex.synchronize do
          cached = cache[url]
          return cached[:token] if cached && cached[:expires_at] > Time.now

          token, expires_in = fetch(url)
          cache[url] = { token:, expires_at: Time.now + expires_in }
          token
        end
      end

      def token_url(service_url)
        uri = URI(service_url)
        origin = "#{uri.scheme}://#{uri.host}"
        origin = "#{origin}:#{uri.port}" if uri.port && uri.port != uri.default_port
        "#{origin}/auth/token"
      end

      def cache
        @cache ||= {}
      end

      def mutex
        @mutex ||= Mutex.new
      end

      def machine_key
        key = ENV.fetch(MACHINE_KEY_ENV, nil)
        return key unless key.nil? || key.empty?

        raise MissingKey, "#{MACHINE_KEY_ENV} is required to call the CRD server"
      end

      def fetch(url)
        response = Faraday.new(url:).post do |request|
          request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
          request.body = URI.encode_www_form(
            grant_type: 'client_credentials',
            client_id: CLIENT_ID,
            client_secret: machine_key
          )
        end
        raise "token exchange failed: #{response.status}" unless response.success?

        body = JSON.parse(response.body)
        [body.fetch('access_token'), body.fetch('expires_in').to_i]
      end
    end
  end
end
