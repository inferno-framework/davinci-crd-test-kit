require 'jwt'
require_relative '../client_urls'
require_relative '../../client_input_helper'
require_relative '../../../cross_suite/request_timeout_handling'

module DaVinciCRDTestKit
  module V221
    class CRDClientRegistrationVerification < Inferno::Test
      include ClientURLs
      include RequestTimeoutHandling

      id :crd_v221_client_registration_verification
      title 'CRD client registration details are complete and valid'
      description %(
        In order to register with and be able to make hook requests against Inferno's
        simulated CRD servers, the tester must provide the `iss` (issuer) claim in
        the payload of the JWT sent in the Authorization header of hook requests
        made by the CRD client against Inferno. This information is used to
        associate inbound requests to Inferno's simulated CRD servers with this session.
        Requests made without a JWT or with a different `iss` value will not appear in this
        session or be analyzed.

        Inferno also requires some additional information to verify that the CRD client behaves
        in a conformant manner. This information is not needed to execute the tests, but the
        tests will not completely pass without it:
        - A JSON Web Key Set (JWKS) containing the key used to sign the JWT sent in the Authorization
          header for use in signature validation. It can be provided either as a URL where it is
          publicly hosted (preferred) or the raw JWKS as JSON.
        - A FHIR Organization id associated with each of Inferno's two simulated CRD servers,
          one at `#{ClientURLs.discovery_url}` requesting the [complete standard prefetch data set](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#standard-prefetch),
          and the other at `#{ClientURLs.prefetch_subset_discovery_url}` requesting a subset of that data set.
          These are used to verify that the prefetched coverage is linked to the correct payer for the invoked
          service.

        During this test, Inferno will verify that the provided registration information is
        complete and valid.
      )

      verifies_requirements 'cds-hooks_3.0.0-ballot@199'

      input :cds_jwt_iss,
            title: 'CRD JWT Issuer',
            description: %(
              Value of the `iss` claim that will be sent in the JWT used to authorize the CRD client's hook
              request sent as the Bearer token in the `Authorization` header.
              This value will be used to associate incoming requests with this test
              session and any requests that use a different `iss` value will not be recognized.
            ),
            type: 'text'
      input :cds_jwk_set,
            title: 'CRD JSON Web Key Set (JWKS)',
            type: 'textarea',
            description: ClientInputHelper.registration_cds_jwk_set_description,
            optional: true
      input :complete_prefetch_service_organization_id,
            title: 'Complete Prefetch Service Organization id',
            description: ClientInputHelper.service_organization_id_description(
              'complete', ClientURLs.discovery_url
            ),
            type: 'text',
            optional: true
      input :subset_prefetch_service_organization_id,
            title: 'Subset Prefetch Service Organization id',
            description: ClientInputHelper.service_organization_id_description(
              'subset', ClientURLs.prefetch_subset_discovery_url
            ),
            type: 'text',
            optional: true

      run do
        if cds_jwk_set.present?
          check_jwks
        else
          add_message('error', 'Provide a jwk set in the **CRD JSON Web Key Set (JWKS)** input.')
        end

        unless complete_prefetch_service_organization_id.present?
          add_message('error', 'Provide an Organization id associated with the Complete Prefetch Service ' \
                               "at endpoint #{discovery_url}")
        end

        unless subset_prefetch_service_organization_id.present?
          add_message('error', 'Provide an Organization id associated with the Subset Prefetch Service ' \
                               "at endpoint #{prefetch_subset_discovery_url}")
        end

        unless complete_prefetch_service_organization_id.present? && subset_prefetch_service_organization_id.present? &&
               complete_prefetch_service_organization_id != subset_prefetch_service_organization_id
          add_message('error', 'Each Inferno CRD service must be assigned a unique Organization id.')
        end

        assert_no_error_messages 'Invalid registration information provided. See Messages for details.'
      end

      def check_jwks
        jwks_warnings = []
        parsed_jwk_set = jwk_set(cds_jwk_set, jwks_warnings)
        jwks_warnings.each { |warning| add_message('warning', warning) }

        add_message('error', 'JWKS content does not include any valid keys.') unless parsed_jwk_set.length.positive?
      end

      def jwk_set(jku, warning_messages = []) # rubocop:disable Metrics/CyclomaticComplexity
        jwk_set = JWT::JWK::Set.new

        if jku.blank?
          warning_messages << 'No key set input.'
          return jwk_set
        end

        jwk_body = # try as raw jwk set
          begin
            JSON.parse(jku)
          rescue JSON::ParserError
            nil
          end

        if jwk_body.nil?
          jwk_body = fetch_jwk_set(jku, warning_messages) # try as url pointing to a jwk set
        else
          warning_messages << 'Providing the JWK Set directly is strongly discouraged.'
        end

        return jwk_set if jwk_body.nil?

        unless jwk_body.is_a?(Hash)
          warning_messages << 'JWKS content is not a JSON object.'
          return jwk_set
        end

        unless jwk_body['keys'].is_a?(Array)
          warning_messages << 'JWKS `keys` field is missing or is not an array.'
          return jwk_set
        end

        jwk_body['keys'].each_with_index do |key_hash, index|
          parsed_key = parse_key(key_hash, index, warning_messages)
          jwk_set << parsed_key unless parsed_key.blank?
        end

        jwk_set
      end

      def parse_key(key_hash, index, warning_messages)
        unless key_hash.is_a?(Hash)
          warning_messages << "Key #{index} invalid: not a JSON object."
          return
        end

        JWT::JWK.new(key_hash)
      rescue StandardError => e # malformed key values raise errors from JWT, OpenSSL, and Ruby itself
        id = key_hash['kid'] || index
        warning_messages << "Key #{id} invalid: #{e}"
        nil
      end

      # A bare Faraday request, so connection failures and timeouts arrive here unhandled by Inferno.
      def fetch_jwk_set(jku, warning_messages)
        unless jwks_url?(jku)
          warning_messages << 'JWKS input is neither a valid JSON Web Key Set nor an http(s) URL.'
          return
        end

        response = jwks_connection.get(jku)
        unless response.status == 200
          warning_messages << "Unexpected response status from JWKS URL #{jku}: expected 200, but received " \
                              "#{response.status}."
          return
        end

        JSON.parse(response.body)
      rescue JSON::ParserError
        warning_messages << "Failed to fetch valid JSON from JWKS URL #{jku}."
        nil
      rescue Faraday::Error => e
        warning_messages << if timeout?(e)
                              request_timed_out_message("JWKS URL `#{jku}`")
                            else
                              "Failed to fetch JWKS from #{jku}: #{e.message}"
                            end
        nil
      end

      def jwks_url?(jku)
        uri = URI.parse(jku)
        uri.host.present? && ['http', 'https'].include?(uri.scheme)
      rescue URI::InvalidURIError
        false
      end

      def jwks_connection
        Faraday.new(request: { open_timeout: REQUEST_TIMEOUT_SECONDS, timeout: REQUEST_TIMEOUT_SECONDS }) do |f|
          f.use FaradayMiddleware::FollowRedirects # as Inferno's `get` does
        end
      end
    end
  end
end
