module DaVinciCRDTestKit
  class TokenHeaderTest < Inferno::Test
    id :crd_token_header
    title 'Authorization token header contains required information'
    description %(
      Verify that the JWT header contains the header fields required by the [CDS hooks spec](https://cds-hooks.hl7.org/2.0#trusting-cds-clients).
      The `alg`, `kid`, and `typ` fields are required. This test also verifies that the `typ` field is set to `JWT` and
      that the key used to sign the token can be identified in the JWKS.
    )

    input :auth_token_header_json, :crd_jwks_keys_json
    output :auth_token_jwk_json

    run do
      header = JSON.parse(auth_token_header_json)

      algorithm = header['alg']
      assert algorithm.present?, 'Token header must have the `alg` field'
      assert algorithm != 'none', 'Token header `alg` field cannot be set to none'

      assert header['typ'].present?, 'Token header must have the `typ` field'
      assert header['typ'] == 'JWT', "Token header `typ` field must be set to 'JWT', instead was #{header['typ']}"

      assert header['kid'].present?, 'Token header must have the `kid` field'
      kid = header['kid']
      keys = JSON.parse(crd_jwks_keys_json)

      jwk = keys.find { |key| key['kid'] == kid }
      assert jwk.present?, "JWKS did not contain a public key with an id of `#{kid}`"

      output auth_token_jwk_json: jwk.to_json
    end
  end
end
