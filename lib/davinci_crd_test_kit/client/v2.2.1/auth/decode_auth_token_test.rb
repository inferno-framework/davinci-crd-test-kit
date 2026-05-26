require_relative '../../multi_request_message_helper'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class DecodeAuthTokenTest < Inferno::Test
      include DaVinciCRDTestKit::MultiRequestMessageHelper
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      id :crd_v221_decode_auth_token
      title 'Bearer tokens can be decoded'
      description %(
        During this test, Inferno will verify that for each request the Bearer token is a properly constructed JWT.
        As per the [CDS hooks specification](https://cds-hooks.hl7.org/2026Jan/en/#trusting-cds-clients),
        each time a CDS client transmits a request to a CDS Service which requires authentication, the request MUST
        include an Authorization header presenting the JWT as a "Bearer" token.
      )

      verifies_requirements 'cds-hooks_3.0.0-ballot@178'

      output :auth_tokens, :auth_token_payloads_json, :auth_token_headers_json

      run do
        load_hook_requests
        skip_if requests.empty?, "No #{hook_name} requests were made in a previous test as expected."
        auth_tokens = []
        auth_token_payloads_json = []
        auth_token_headers_json = []

        requests.each_with_index do |request, index|
          authorization_header = request.request_header('Authorization')&.value

          unless authorization_header&.start_with?('Bearer ')
            add_request_message('error', 'Authorization token must be a JWT presented as a `Bearer` token', index)
            auth_tokens << nil
            auth_token_payloads_json << nil
            auth_token_headers_json << nil
            next
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
            add_request_message('error', "Token is not a properly constructed JWT: #{e.message}", index)
            auth_token_payloads_json << nil
            auth_token_headers_json << nil
          end
        end
        output auth_tokens: auth_tokens.to_json,
               auth_token_payloads_json: auth_token_payloads_json.to_json,
               auth_token_headers_json: auth_token_headers_json.to_json

        assert_no_error_messages("#{requests_with_errors_prefix}Decoding Authorization header Bearer tokens failed. " \
                                 'See Messages for details.')
      end
    end
  end
end
