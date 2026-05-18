require_relative '../../multi_request_message_helper'

module DaVinciCRDTestKit
  module V221
    class RetrieveJWKSTest < Inferno::Test
      include DaVinciCRDTestKit::MultiRequestMessageHelper

      id :crd_v221_retrieve_jwks
      title 'JWKSs can be retrieved'
      description %(
        During this test, Inferno will verify that for each request the JWKS can be retrieved from the JWKS uri if
        it is present in the `jku` field within the JWT token header. Additionally, keys will be extracted and
        outputted for use in subsequent tests. If the client does not provide a uri in the `jku` field,
        Inferno will extract keys from the raw JWKS JSON provided out of band as a part of the "Registration" group.
      )

      verifies_requirements 'cds-hooks_3.0.0-ballot@183', 'cds-hooks_3.0.0-ballot@185', 'cds-hooks_3.0.0-ballot@197',
                            'cds-hooks_3.0.0-ballot@199'

      input :auth_token_headers_json
      input :cds_jwk_set,
            title: 'CRD JSON Web Key Set (JWKS)',
            type: 'textarea',
            description: %(
            The client's registered JWK Set containing it's public key. Used
            only when a request was received with a JWT without the `jku` header.
            Inferno assumes this input, provided during the "Registration"
            group, contains the raw JSON representation of a JWKS (if a URI was provided
            it would be populated in the `jku` header). Run or re-run the "Registration"
            group to set or change this value.
          ),
            locked: true,
            optional: true
      output :crd_jwks_keys_json

      run do
        auth_token_headers = JSON.parse(auth_token_headers_json) # NOTE: pre-verified json
        skip_if auth_token_headers.compact.empty?, 'No Authorization tokens produced from the previous test.'
        skip_if cds_jwk_set.blank? && cds_jwk_set_input_needed?(auth_token_headers),
                "JWK Set must be inputted if the client's JWK Set is not available"

        crd_jwks_keys_json = []
        auth_token_headers.each_with_index do |token_header, index|
          unless token_header.present?
            crd_jwks_keys_json << nil
            next
          end

          jku = JSON.parse(token_header)['jku'] # NOTE: pre-verified json
          jwks =
            if jku.present?
              get(jku)

              if response[:status] == 200
                parse_json_request_entity(response[:body], 'Fetched jku url response', index)
              else
                add_request_message('error',
                                    "Unexpected response status: expected 200, but received #{response[:status]}",
                                    index)
                nil
              end
            else
              parse_json_request_entity(cds_jwk_set, 'JWK Set input', index)
            end
          if jwks.blank?
            crd_jwks_keys_json << nil
            next
          end

          keys = jwks['keys']
          unless keys.is_a?(Array)
            add_request_message('error', 'JWKS `keys` field must be an array', index)
            crd_jwks_keys_json << nil
            next
          end

          if keys.blank?
            add_request_message('error', 'The JWK set returned contains no public keys', index)
            crd_jwks_keys_json << nil
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
            crd_jwks_keys_json << nil
            next
          end

          kid_uniqueness = keys.map { |key| key['kid'] }.uniq.length == keys.length
          if kid_uniqueness.blank?
            add_request_message('error', "`kid` must be unique within the client's JWK Set.", index)
            crd_jwks_keys_json << nil
            next
          end

          crd_jwks_keys_json << keys.to_json
        end

        output crd_jwks_keys_json: crd_jwks_keys_json.to_json

        assert_no_error_messages("#{requests_with_errors_prefix}Retrieving JWKS failed. See Messages for details.")
      end

      def cds_jwk_set_input_needed?(auth_token_headers)
        auth_token_headers.any? do |token_header|
          token_header.present? && JSON.parse(token_header)['jku'].blank?
        end
      end
    end
  end
end
