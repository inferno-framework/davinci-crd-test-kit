require 'jwt'

module DaVinciCRDTestKit
  class CRDClientRegistrationVerification < Inferno::Test
    include URLs

    id :crd_client_registration_verification
    title 'Verify CRD Client Registration'
    description %(
        During this test, Inferno will verify that the CRD Client registration details
        provided are conformant.
      )

    verifies_requirements 'cds-hooks_2.0@197' # 'cds-hooks_2.0@174' - TODO: move to an attestation test

    input :cds_jwt_iss,
          title: 'CRD JWT Issuer',
          description: %(
            The `iss` claim of the JWT in the Authorization header sent by the CRD client under test on
            all CRD requests. This value will be used to associate incoming requests with this test
            session and any requests that use a different `iss` value will not be recognized.
          ),
          type: 'text'
    input :cds_jwk_set,
          title: 'CRD JSON Web Key Set (JWKS)',
          type: 'textarea',
          description: %(
            The CRD client's JWK Set containing it's public key. May be either
            a publicly accessible url containing the JWKS, or the raw JWKS.
            This input is required for these tests to pass.
          ),
          optional: true

    run do
      assert cds_jwk_set.present?, 'Provide a jwk set in the **CRD JSON Web Key Set (JWKS)** input.'

      jwks_warnings = []
      parsed_jwk_set = jwk_set(cds_jwk_set, jwks_warnings)
      jwks_warnings.each { |warning| add_message('warning', warning) }

      assert parsed_jwk_set.length.positive?, 'JWKS content does not include any valid keys.'

      assert messages.none? { |msg| msg[:type] == 'error' }, 'Invalid key set provided. See messages for details'
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

      if jwk_body.blank?
        retrieved = Faraday.get(jku) # try as url pointing to a jwk set
        jwk_body =
          begin
            JSON.parse(retrieved.body)
          rescue JSON::ParserError
            warning_messages << "Failed to fetch valid json from jwks uri #{jku}."
            nil
          end
      else
        warning_messages << 'Providing the JWK Set directly is strongly discouraged.'
      end

      return jwk_set if jwk_body.blank?

      jwk_body['keys']&.each_with_index do |key_hash, index|
        parsed_key =
          begin
            JWT::JWK.new(key_hash)
          rescue JWT::JWKError => e
            id = key_hash['kid'] | index
            warning_messages << "Key #{id} invalid: #{e}"
            nil
          end
        jwk_set << parsed_key unless parsed_key.blank?
      end

      jwk_set
    end
  end
end
