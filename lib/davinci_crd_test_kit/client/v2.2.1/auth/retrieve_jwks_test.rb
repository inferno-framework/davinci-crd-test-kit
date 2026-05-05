require_relative '../../multi_request_message_helper'

module DaVinciCRDTestKit
  module V221
    class RetrieveJWKSTest < Inferno::Test
      include DaVinciCRDTestKit::MultiRequestMessageHelper

      id :crd_v221_retrieve_jwks
      title 'JWKS can be retrieved'
      description %(
        Verify that the JWKS can be retrieved from the JWKS uri if it is present in the `jku` field within the JWT token
        header. As per the [CDS hooks specification](https://cds-hooks.hl7.org/2.0#trusting-cds-clients), if the jku
        header field is omitted, the CDS Client and CDS Service SHALL communicate the JWK Set out-of-band. Therefore,
        if the client does not make their keys publicly available via a uri in the `jku` field, the user must
        submit the jwk_set as an input to the test.
      )

      # verifies_requirements 'cds-hooks_2.0@183', 'cds-hooks_2.0@185', 'cds-hooks_2.0@197', 'cds-hooks_2.0@199'

      input :auth_token_headers_json
      input :cds_jwk_set,
            title: 'CRD JSON Web Key Set (JWKS)',
            type: 'textarea',
            description: %(
            The client's registered JWK Set containing it's public key, either
            as a publicly accessible url containing the JWKS, or the raw JWKS.
            Run or re-run the **Client Registration** group to set or
            change this value. Used if the `jku` header is not found in the auth token jwt.
          ),
            locked: true,
            optional: true
      output :crd_jwks_json, :crd_jwks_keys_json

      run do
        auth_token_headers = JSON.parse(auth_token_headers_json) # NOTE: pre-verified json
        skip_if auth_token_headers.empty?, 'No Authorization tokens produced from the previous test.'

        crd_jwks_json = []
        crd_jwks_keys_json = []
        auth_token_headers.each_with_index do |token_header, index|
          jku = JSON.parse(token_header)['jku'] # NOTE: pre-verified json
          if jku.present?
            get(jku)

            if response[:status] != 200
              add_request_message('error',
                                  "Unexpected response status: expected 200, but received #{response[:status]}",
                                  index)
              next
            end

            jwks = parse_json_request_entity(response[:body], 'Fetched jku url response', index)
            next if jwks.blank?

            crd_jwks_json << response[:body]
          else
            skip_if cds_jwk_set.blank?,
                    "JWK Set must be inputted if Client's JWK Set is not available via a URL " \
                    'identified by the jku header field'

            jwks = parse_json_request_entity(cds_jwk_set, 'JWK Set input', index)
            next if jwks.blank?
          end

          keys = jwks['keys']
          unless keys.is_a?(Array)
            add_request_message('error', 'JWKS `keys` field must be an array', index)
            next
          end

          if keys.blank?
            add_request_message('error', 'The JWK set returned contains no public keys', index)
            next
          end

          keys.each do |jwk|
            JWT::JWK.import(jwk.deep_symbolize_keys)
          rescue StandardError
            add_request_message('error', "Invalid JWK: #{jwk.to_json}", index)
          end

          kid_presence = keys.all? { |key| key['kid'].present? }
          if kid_presence.blank?
            add_request_message('error',
                                '`kid` field must be present in each key if JWKS contains multiple keys',
                                index)
            next
          end

          kid_uniqueness = keys.map { |key| key['kid'] }.uniq.length == keys.length
          if kid_uniqueness.blank?
            add_request_message('error', "`kid` must be unique within the client's JWK Set.", index)
            next
          end

          crd_jwks_keys_json << keys.to_json
        end

        output crd_jwks_json: crd_jwks_json.to_json,
               crd_jwks_keys_json: crd_jwks_keys_json.to_json

        assert_no_error_messages("#{requests_with_errors_prefix}Retrieving JWKS failed. See Messages for details.")
      end
    end
  end
end
