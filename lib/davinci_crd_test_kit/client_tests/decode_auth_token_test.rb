module DaVinciCRDTestKit
  class DecodeAuthTokenTest < Inferno::Test
    id :crd_decode_auth_token
    title 'Bearer token can be decoded'
    description %(
        Verify that the Bearer token is a properly constructed JWT. As per the [CDS hooks specification](https://cds-hooks.hl7.org/2.0#trusting-cds-clients),
        each time a CDS Client transmits a request to a CDS Service which requires authentication, the request MUST
        include an Authorization header presenting the JWT as a "Bearer" token.
      )

    output :auth_tokens, :auth_token_payloads_json, :auth_tokens_header_json

    def hook_name
      config.options[:hook_name]
    end

    run do
      load_tagged_requests(hook_name)
      skip_if requests.empty?, "No #{hook_name} requests were made in a previous test as expected."
      skip_if(requests.none? { |request| request.request_header('Authorization')&.value.present? },
              "No #{hook_name} requests contained the Authorization header")
      error_messages = []
      auth_tokens = []
      auth_token_payloads_json = []
      auth_tokens_header_json = []

      requests.each_with_index do |request, index|
        authorization_header = request.request_header('Authorization')&.value
        info do
          assert authorization_header.present?, "Request #{index + 1} does not include an Authorization header"
        end
        next if authorization_header.blank?

        assert(authorization_header.start_with?('Bearer '),
               'Authorization token must be a JWT presented as a `Bearer` token')

        auth_token = authorization_header.delete_prefix('Bearer ')
        auth_tokens << auth_token

        begin
          payload, header =
            JWT.decode(
              auth_token,
              nil,
              false
            )

          auth_token_payloads_json << payload.to_json
          auth_tokens_header_json << header.to_json
        rescue StandardError => e
          assert false, "Token is not a properly constructed JWT: #{e.message}"
        end
      rescue Inferno::Exceptions::AssertionException => e
        error_messages << "Request #{index + 1}: #{e.message}"
      end
      output auth_tokens: auth_tokens.to_json,
             auth_token_payloads_json: auth_token_payloads_json.to_json,
             auth_tokens_header_json: auth_tokens_header_json.to_json

      error_messages.each do |msg|
        messages << { type: 'error', message: msg }
      end
      assert error_messages.empty?, 'Decoding Authorization header Bearer tokens failed.'
    end
  end
end
