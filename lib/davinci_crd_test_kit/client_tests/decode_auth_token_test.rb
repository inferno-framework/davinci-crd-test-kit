require_relative '../client_hook_request_validation'

module DaVinciCRDTestKit
  class DecodeAuthTokenTest < Inferno::Test
    include ClientHookRequestValidation
    id :crd_decode_auth_token
    title 'Bearer token can be decoded'
    description %(
        Verify that the Bearer token is a properly constructed JWT. As per the [CDS hooks specification](https://cds-hooks.hl7.org/2.0#trusting-cds-clients),
        each time a CDS Client transmits a request to a CDS Service which requires authentication, the request MUST
        include an Authorization header presenting the JWT as a "Bearer" token.
      )

    verifies_requirements 'cds-hooks_2.0@178'

    output :auth_tokens, :auth_token_payloads_json, :auth_token_headers_json

    def hook_name
      config.options[:hook_name]
    end

    run do
      load_tagged_requests(hook_name)
      skip_if requests.empty?, "No #{hook_name} requests were made in a previous test as expected."
      auth_tokens = []
      auth_token_payloads_json = []
      auth_token_headers_json = []

      requests.each_with_index do |request, index|
        @request_number = index + 1

        authorization_header = request.request_header('Authorization')&.value

        unless authorization_header.start_with?('Bearer ')
          add_message('error', "#{request_number}Authorization token must be a JWT presented as a `Bearer` token")
        end

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
          auth_token_headers_json << header.to_json
        rescue StandardError => e
          add_message('error', "#{request_number}Token is not a properly constructed JWT: #{e.message}")
        end
      end
      output auth_tokens: auth_tokens.to_json,
             auth_token_payloads_json: auth_token_payloads_json.to_json,
             auth_token_headers_json: auth_token_headers_json.to_json

      no_error_validation('Decoding Authorization header Bearer tokens failed.')
    end
  end
end
