require_relative '../client_hook_request_validation'

module DaVinciCRDTestKit
  class TokenHeaderTest < Inferno::Test
    include ClientHookRequestValidation

    id :crd_token_header
    title 'Authorization token header contains required information'
    description %(
      Verify that the JWT header contains the header fields required by the [CDS hooks spec](https://cds-hooks.hl7.org/2.0#trusting-cds-clients).
      The `alg`, `kid`, and `typ` fields are required. This test also verifies that the `typ` field is set to `JWT` and
      that the key used to sign the token can be identified in the JWKS.
    )

    input :auth_token_headers_json, :crd_jwks_keys_json
    output :auth_tokens_jwk_json

    run do
      auth_token_headers = JSON.parse(auth_token_headers_json)
      crd_jwks_keys = JSON.parse(crd_jwks_keys_json)
      skip_if auth_token_headers.empty?, 'No Authorization tokens produced from the previous tests.'
      skip_if crd_jwks_keys.empty?, 'No JWKS keys produced from the previous test.'

      auth_tokens_jwk_json = []
      auth_token_headers.each_with_index do |token_header, index|
        @request_number = index + 1

        header = JSON.parse(token_header)
        algorithm = header['alg']

        add_message('error', "#{request_number}Token header must have the `alg` field") if algorithm.blank?

        add_message('error', "#{request_number}Token header `alg` field cannot be set to none") if algorithm == 'none'

        if header['typ'].blank?
          add_message('error', "#{request_number}Token header must have the `typ` field")
        elsif header['typ'] != 'JWT'
          add_message('error', %(
                      #{request_number}Token header `typ` field must be set to 'JWT', instead was
                      #{header['typ']}))
        end

        if header['kid'].blank?
          add_message('error', "#{request_number}Token header must have the `kid` field")
          next
        end

        kid = header['kid']
        keys = JSON.parse(crd_jwks_keys[index])

        jwk = keys.find { |key| key['kid'] == kid }
        if jwk.blank?
          add_message('error', "#{request_number}JWKS did not contain a public key with an id of `#{kid}`")
          next
        end

        auth_tokens_jwk_json << jwk.to_json
      end

      output auth_tokens_jwk_json: auth_tokens_jwk_json.to_json

      no_error_validation('Token headers missing required information.')
    end
  end
end
