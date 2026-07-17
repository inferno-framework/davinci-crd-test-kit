require_relative '../../multi_request_message_helper'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class TokenPayloadTest < Inferno::Test
      include DaVinciCRDTestKit::MultiRequestMessageHelper
      include DaVinciCRDTestKit::TaggedRequestLoadHelper
      include ClientURLs

      id :crd_v221_token_payload
      title 'Authorization token payloads have required claims and valid signatures'
      description %(
        During this test, Inferno will verify that for each request the JWT payload is conformant to the
        requirements in the [CDS hooks specification](https://cds-hooks.hl7.org/2026Jan/en/#trusting-cds-clients),
        including the following:
        - The `iss`, `aud`, `exp`, `iat`, and `jti` claims are required.
        - `iss` must match the `issuer` from the **CRD JWT Issuer** input.
        - `aud` must match the URL of the CDS Service endpoint being invoked.
        - `exp` must represent a time in the future.
        - `jti` must be a non-blank string that uniquely identifies this authentication JWT.
      )

      verifies_requirements 'cds-hooks_3.0.0-ballot@180', 'cds-hooks_3.0.0-ballot@181', 'cds-hooks_3.0.0-ballot@187',
                            'cds-hooks_3.0.0-ballot@189', 'cds-hooks_3.0.0-ballot@190', 'cds-hooks_3.0.0-ballot@191',
                            'cds-hooks_3.0.0-ballot@192', 'cds-hooks_3.0.0-ballot@196', 'cds-hooks_3.0.0-ballot@203'

      REQUIRED_CLAIMS = ['iss', 'aud', 'exp', 'iat', 'jti'].freeze

      def required_claims
        REQUIRED_CLAIMS.dup
      end

      # Replace the scheme+host of request.url with the configured external host
      # so that aud validation works correctly when Inferno is behind a reverse proxy.
      def public_hook_url(request)
        hook_suffix = URI.parse(request.url).path.delete_prefix(URI.parse(inferno_base_url).path)
        inferno_base_url + hook_suffix
      end

      input :auth_tokens,
            :auth_tokens_jwk_json,
            :cds_jwt_iss

      run do
        auth_tokens_list = JSON.parse(auth_tokens)
        auth_tokens_jwk = JSON.parse(auth_tokens_jwk_json)
        requests = load_hook_requests
        skip_if auth_tokens_list.compact.empty?, 'No Authorization tokens produced from the previous tests.'
        skip_if auth_tokens_jwk.compact.empty?, 'No Authorization token JWK produced from the previous test.'

        auth_tokens_jwk.each_with_index do |auth_token_jwk, index|
          next unless auth_token_jwk.present?

          request = requests[index]

          begin
            jwk = JSON.parse(auth_token_jwk).deep_symbolize_keys # NOTE: pre-verified json
            unverified_payload, jwt_header = JWT.decode(auth_tokens_list[index], nil, false)
          rescue StandardError => e
            add_request_message('error', "Token validation error: #{e.message}", index)
            next
          end

          alg = jwk[:alg] || jwt_header['alg']

          # Continue checking the rest of the token even when one check fails, so the tester sees every
          # issue at once rather than fixing them one error at a time.
          # CDS Hooks prohibits the `none` algorithm and symmetric (HMAC) algorithms for the authentication JWT.
          if alg.to_s.match?(/\A(none|hs\d+)\z/i)
            add_request_message('error',
                                "Token signature algorithm #{alg.inspect} is not permitted; CDS Hooks prohibits " \
                                'the `none` algorithm and symmetric (HMAC) algorithms.', index)
          else
            begin
              JWT.decode(
                auth_tokens_list[index],
                JWT::JWK.import(jwk).public_key,
                true,
                algorithms: [alg],
                exp_leeway: 60,
                iss: cds_jwt_iss,
                aud: public_hook_url(request),
                verify_not_before: false,
                verify_iat: false,
                verify_jti: true,
                verify_iss: true,
                verify_aud: true
              )
            rescue StandardError => e
              add_request_message('error', "Token validation error: #{e.message}", index)
            end
          end

          missing_claims = required_claims - unverified_payload.keys
          next if missing_claims.empty?

          missing_claims_string = missing_claims.map { |claim| "`#{claim}`" }.join(', ')
          add_request_message('error', "JWT payload missing required claims: #{missing_claims_string}", index)
        end
        assert_no_error_messages("#{requests_with_errors_prefix}Token payload is missing required claims or " \
                                 'does not have a valid signature. See Messages for details.')
      end
    end
  end
end
