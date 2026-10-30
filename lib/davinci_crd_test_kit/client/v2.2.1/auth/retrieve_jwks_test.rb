require_relative '../../multi_request_message_helper'
require_relative '../../../cross_suite/short_circuit_interaction'
require_relative '../../../cross_suite/request_timeout_handling'

module DaVinciCRDTestKit
  module V221
    class RetrieveJWKSTest < Inferno::Test
      include DaVinciCRDTestKit::MultiRequestMessageHelper
      include DaVinciCRDTestKit::ShortCircuitInteraction
      include DaVinciCRDTestKit::RequestTimeoutHandling

      id :crd_v221_retrieve_jwks
      title 'CRD client JWKS can be retrieved'
      description %(
        During this test, Inferno will verify that for each request the CRD client's JWKS can be retrieved
        from the URL in the `jku` field of the JWT header, when present. If the JWT header has no `jku`
        field, Inferno uses the JWKS provided in the "Registration" group instead, either retrieving it
        from the provided URL or reading the raw JWKS JSON. The keys in the JWKS are then saved as an output
        for use in subsequent tests.
      )

      verifies_requirements 'cds-hooks_3.0.0-ballot@183', 'cds-hooks_3.0.0-ballot@185', 'cds-hooks_3.0.0-ballot@197',
                            'cds-hooks_3.0.0-ballot@199'

      # Optional so that a group whose requests were declined can pass rather than skip on an input
      # the short circuited test before it never produced. The run block still skips when empty.
      # The default only pre-fills the UI, so a missing value still arrives as nil.
      input :auth_token_headers_json, optional: true, default: '[]'
      input :cds_jwk_set,
            title: 'CRD JSON Web Key Set (JWKS)',
            type: 'textarea',
            description: %(
            The CRD client's registered JWK Set, provided during the "Registration" group, containing
            its public key. Used only when a request was received with a JWT without the `jku`
            header. May be either a publicly accessible URL containing the JWKS, or the raw JWKS
            JSON. Run or re-run the "Registration" group to set or change this value.
          ),
            locked: true,
            optional: true
      output :crd_jwks_keys_json

      run do
        check_for_short_circuit

        # replace any output from an earlier run so that later tests skip rather than reuse stale keys
        output crd_jwks_keys_json: '[]'
        auth_token_headers = JSON.parse(auth_token_headers_json.presence || '[]') # NOTE: pre-verified json
        skip_if auth_token_headers.compact.empty?, 'No Authorization tokens produced from the previous test.'
        skip_if cds_jwk_set.blank? && cds_jwk_set_input_needed?(auth_token_headers),
                'A request JWT has no `jku` header, so the CRD client\'s JWKS must be provided in the ' \
                '**CRD JSON Web Key Set (JWKS)** input. Re-run the "Registration" group to provide it.'

        crd_jwks_keys_json = []
        auth_token_headers.each_with_index do |token_header, index|
          unless token_header.present?
            crd_jwks_keys_json << nil
            next
          end

          jku = JSON.parse(token_header)['jku'] # NOTE: pre-verified json
          jwks =
            if jku.present?
              fetch_jwks(jku, 'Fetched jku url response', index)
            else
              parse_or_fetch_jwks(cds_jwk_set, index)
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
            add_request_message('error', "`kid` must be unique within the CRD client's JWK Set.", index)
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

      def fetch_jwks(uri, entity, index)
        get(uri)

        if response[:status] == 200
          parse_json_request_entity(response[:body], entity, index)
        else
          add_request_message('error',
                              "Unexpected response status: expected 200, but received #{response[:status]}",
                              index)
          nil
        end
      rescue *REQUEST_TIMEOUT_ERRORS
        add_request_message('error', request_timed_out_message("JWKS URL `#{uri}`"), index)
        nil
      rescue Inferno::Exceptions::AssertionException => e
        # Inferno turns a connection that can't be opened, including one that times out, into a
        # failure, which would end the test before the other requests are checked.
        message = timeout?(e.cause) ? request_timed_out_message("JWKS URL `#{uri}`") : e.message
        add_request_message('error', message, index)
        nil
      end

      def parse_or_fetch_jwks(jwk_set_input, index)
        if jwk_set_input.match?(%r{\Ahttps?://})
          fetch_jwks(jwk_set_input, 'Fetched JWK Set input url response', index)
        else
          parse_json_request_entity(jwk_set_input, 'JWK Set input', index)
        end
      end
    end
  end
end
