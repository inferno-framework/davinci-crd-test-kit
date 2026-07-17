require_relative '../../client_hook_request_validation'

module DaVinciCRDTestKit
  module V201
    class TokenPayloadTest < Inferno::Test
      include ClientHookRequestValidation
      include ClientURLs

      id :crd_v201_token_payload
      title 'Authorization token payload has required claims and a valid signature'
      description %(
        Verify that the JWT payload contains the payload fields required by the
        [CDS hooks spec](https://cds-hooks.hl7.org/2.0#trusting-cds-clients).
        The `iss`, `aud`, `exp`, `iat`, and `jti` claims are required.
        Additionally:

        - `iss` must match the `issuer` from the **CRD JWT Issuer** input
        - `aud` must match the URL of the CDS Service endpoint being invoked
        - `exp` must represent a time in the future
        - `jti` must be a non-blank string that uniquely identifies this authentication JWT
      )

      verifies_requirements 'cds-hooks_2.0@180', 'cds-hooks_2.0@181', 'cds-hooks_2.0@187', 'cds-hooks_2.0@189',
                            'cds-hooks_2.0@190', 'cds-hooks_2.0@191', 'cds-hooks_2.0@192', 'cds-hooks_2.0@196',
                            'cds-hooks_2.0@203'

      REQUIRED_CLAIMS = ['iss', 'aud', 'exp', 'iat', 'jti'].freeze

      def required_claims
        REQUIRED_CLAIMS.dup
      end

      def hook_url
        inferno_base_url + config.options[:hook_path]
      end

      input :auth_tokens,
            :auth_tokens_jwk_json,
            :cds_jwt_iss

      run do
        auth_tokens_list = JSON.parse(auth_tokens)
        auth_tokens_jwk = JSON.parse(auth_tokens_jwk_json)
        skip_if auth_tokens_list.empty?, 'No Authorization tokens produced from the previous tests.'
        skip_if auth_tokens_jwk.empty?, 'No Authorization token JWK produced from the previous test.'

        auth_tokens_jwk.each_with_index do |auth_token_jwk, index|
          @request_number = index + 1

          begin
            jwk = JSON.parse(auth_token_jwk).deep_symbolize_keys
            unverified_payload, jwt_header = JWT.decode(auth_tokens_list[index], nil, false)
          rescue StandardError => e
            add_message('error', "#{request_number}Token validation error: #{e.message}")
            next
          end

          alg = jwk[:alg] || jwt_header['alg']

          # Continue checking the rest of the token even when one check fails, so the tester sees every
          # issue at once rather than fixing them one error at a time.
          # CDS Hooks prohibits the `none` algorithm and symmetric (HMAC) algorithms for the authentication JWT.
          if alg.to_s.match?(/\A(none|hs\d+)\z/i)
            add_message('error',
                        "#{request_number}Token signature algorithm #{alg.inspect} is not permitted; CDS Hooks " \
                        'prohibits the `none` algorithm and symmetric (HMAC) algorithms.')
          else
            begin
              JWT.decode(
                auth_tokens_list[index],
                JWT::JWK.import(jwk).public_key,
                true,
                algorithms: [alg],
                exp_leeway: 60,
                iss: cds_jwt_iss,
                aud: hook_url,
                verify_not_before: false,
                verify_iat: false,
                verify_jti: true,
                verify_iss: true,
                verify_aud: true
              )
            rescue StandardError => e
              add_message('error', "#{request_number}Token validation error: #{e.message}")
            end
          end

          missing_claims = required_claims - unverified_payload.keys
          next if missing_claims.empty?

          missing_claims_string = missing_claims.map { |claim| "`#{claim}`" }.join(', ')
          add_message('error', "#{request_number}JWT payload missing required claims: #{missing_claims_string}")
        end
        no_error_validation('Token payload is missing required claims or does not have a valid signature.')
      end
    end
  end
end
