module DaVinciCRDTestKit
  class TokenPayloadTest < Inferno::Test
    include URLs
    id :crd_token_payload
    title 'Authorization token payload has required claims and a valid signature'
    description %(
      Verify that the JWT payload contains the payload fields required by the
      [CDS hooks spec](https://cds-hooks.hl7.org/2.0#trusting-cds-clients).
      The `iss`, `aud`, `exp`, `iat`, and `jti` claims are required.
      Additionally:

      - `iss` must match the `issuer` from the `iss` input
      - `aud` must match the URL of the CDS Service endpoint being invoked
      - `exp` must represent a time in the future
      - `jti` must be a non-blank string that uniquely identifies this authentication JWT
    )

    REQUIRED_CLAIMS = ['iss', 'aud', 'exp', 'iat', 'jti'].freeze

    def required_claims
      REQUIRED_CLAIMS.dup
    end

    def hook_url
      base_url + config.options[:hook_path]
    end

    input :auth_tokens,
          :auth_tokens_jwk_json,
          :iss

    run do
      auth_tokens_list = JSON.parse(auth_tokens)
      auth_tokens_jwk = JSON.parse(auth_tokens_jwk_json)
      skip_if auth_tokens_list.empty?, 'No Authorization tokens produced from the previous tests.'
      skip_if auth_tokens_jwk.empty?, 'No Authorization token JWK produced from the previous test.'

      error_messages = []
      auth_tokens_jwk.each_with_index do |auth_token_jwk, index|
        begin
          jwk = JSON.parse(auth_token_jwk).deep_symbolize_keys

          payload, =
            JWT.decode(
              auth_tokens_list[index],
              JWT::JWK.import(jwk).public_key,
              true,
              algorithms: [jwk[:alg]],
              exp_leeway: 60,
              iss:,
              aud: hook_url,
              verify_not_before: false,
              verify_iat: false,
              verify_jti: true,
              verify_iss: true,
              verify_aud: true
            )
        rescue StandardError => e
          assert false, "Token validation error: #{e.message}"
        end

        missing_claims = required_claims - payload.keys
        missing_claims_string = missing_claims.map { |claim| "`#{claim}`" }.join(', ')

        assert missing_claims.empty?, "JWT payload missing required claims: #{missing_claims_string}"
      rescue Inferno::Exceptions::AssertionException => e
        error_messages << "Request #{index + 1}: #{e.message}"
      end

      error_messages.each do |msg|
        messages << { type: 'error', message: msg }
      end
      assert error_messages.empty?, 'Token payload is missing required claims or does not have a valid signiture.'
    end
  end
end
