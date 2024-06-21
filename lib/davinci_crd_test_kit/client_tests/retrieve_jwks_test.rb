require_relative '../client_hook_request_validation'

module DaVinciCRDTestKit
  class RetrieveJWKSTest < Inferno::Test
    include ClientHookRequestValidation

    id :crd_retrieve_jwks
    title 'JWKS can be retrieved'
    description %(
        Verify that the JWKS can be retrieved from the JWKS uri if it is present in the `jku` field within the JWT token
        header. As per the [CDS hooks specification](https://cds-hooks.hl7.org/2.0#trusting-cds-clients), if the jku
        header field is ommitted, the CDS Client and CDS Service SHALL communicate the JWK Set out-of-band. Therefore,
        if the client does not make their keys publicly available via a uri in the `jku` field, the user must
        submit the jwk_set as an input to the test.
      )

    input :auth_token_headers_json
    input :jwk_set,
          title: "The Client's JWK Set containing it's public key",
          description: %(
            Must supply if you do not make your keys publicly available via a uri in the authorization JWT header `jku`
            field'
          ),
          type: 'textarea',
          optional: true
    output :crd_jwks_json, :crd_jwks_keys_json

    run do
      auth_token_headers = JSON.parse(auth_token_headers_json)
      skip_if auth_token_headers.empty?, 'No Authorization tokens produced from the previous test.'

      crd_jwks_json = []
      crd_jwks_keys_json = []
      auth_token_headers.each_with_index do |token_header, index|
        @request_number = index + 1

        jku = JSON.parse(token_header)['jku']
        if jku.present?
          get(jku)

          if response[:status] != 200
            add_message('error', %(
                        #{request_number}Unexpected response status: expected 200, but received
                        #{response[:status]}))
            next
          end

          @request_number = index + 1
          jwks = json_parse(response[:body])
          next if jwks.blank?

          crd_jwks_json << response[:body]

          jwks = JSON.parse(response[:body])
        else
          skip_if jwk_set.blank?,
                  %(#{request_number}JWK Set must be inputted if Client's JWK Set is not available via a URL
                  identified by the jku header field)

          jwks = JSON.parse(jwk_set)
        end

        keys = jwks['keys']
        unless keys.is_a?(Array)
          add_message('error', "#{request_number}JWKS `keys` field must be an array")
          next
        end

        if keys.blank?
          add_message('error', "#{request_number}The JWK set returned contains no public keys")
          next
        end

        keys.each do |jwk|
          JWT::JWK.import(jwk.deep_symbolize_keys)
        rescue StandardError
          add_message('error', "#{request_number}Invalid JWK: #{jwk.to_json}")
        end

        kid_presence = keys.all? { |key| key['kid'].present? }
        if kid_presence.blank?
          add_message('error',
                      "#{request_number}`kid` field must be present in each key if JWKS contains multiple keys")
          next
        end

        kid_uniqueness = keys.map { |key| key['kid'] }.uniq.length == keys.length
        if kid_uniqueness.blank?
          add_message('error', "#{request_number}`kid` must be unique within the client's JWK Set.")
          next
        end

        crd_jwks_keys_json << keys.to_json
      end

      output crd_jwks_json: crd_jwks_json.to_json,
             crd_jwks_keys_json: crd_jwks_keys_json.to_json

      no_error_validation('Retrieving JWKS failed.')
    end
  end
end
