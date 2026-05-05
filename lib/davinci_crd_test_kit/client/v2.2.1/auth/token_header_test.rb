require_relative '../../multi_request_message_helper'

module DaVinciCRDTestKit
  module V221
    class TokenHeaderTest < Inferno::Test
      include DaVinciCRDTestKit::MultiRequestMessageHelper

      id :crd_v221_token_header
      title 'Authorization token header contains required information'
      description %(
        Verify that the JWT header contains the header fields required by the
        [CDS hooks spec](https://cds-hooks.hl7.org/2.0#trusting-cds-clients).
        The `alg`, `kid`, and `typ` fields are required. This test also verifies that the `typ` field is set to
        `JWT` and that the key used to sign the token can be identified in the JWKS.
      )

      # verifies_requirements 'cds-hooks_2.0@182', 'cds-hooks_2.0@184', 'cds-hooks_2.0@202'

      input :auth_token_headers_json, :crd_jwks_keys_json
      output :auth_tokens_jwk_json

      run do
        auth_token_headers = JSON.parse(auth_token_headers_json)
        crd_jwks_keys = JSON.parse(crd_jwks_keys_json)
        skip_if auth_token_headers.empty?, 'No Authorization tokens produced from the previous tests.'
        skip_if crd_jwks_keys.empty?, 'No JWKS keys produced from the previous test.'

        auth_tokens_jwk_json = []
        auth_token_headers.each_with_index do |token_header, index|
          header = JSON.parse(token_header) # NOTE: pre-verified json
          algorithm = header['alg']

          add_request_message('error', 'Token header must have the `alg` field', index) if algorithm.blank?

          add_request_message('error', 'Token header `alg` field cannot be set to none', index) if algorithm == 'none'

          if header['typ'].blank?
            add_request_message('error', 'Token header must have the `typ` field', index)
          elsif header['typ'] != 'JWT'
            add_request_message('error',
                                "Token header `typ` field must be set to 'JWT', instead was #{header['typ']}",
                                index)
          end

          if header['kid'].blank?
            add_request_message('error', 'Token header must have the `kid` field', index)
            next
          end

          kid = header['kid']
          keys = JSON.parse(crd_jwks_keys[index]) # NOTE: pre-verified json

          jwk = keys.find { |key| key['kid'] == kid }
          if jwk.blank?
            add_request_message('error', "JWKS did not contain a public key with an id of `#{kid}`", index)
            next
          end

          auth_tokens_jwk_json << jwk.to_json
        end

        output auth_tokens_jwk_json: auth_tokens_jwk_json.to_json

        assert_no_error_messages("#{requests_with_errors_prefix}Token header missing required information. " \
                                 'See Messages for details.')
      end
    end
  end
end
