module DaVinciCRDTestKit
  class RetrieveJWKSTest < Inferno::Test
    id :crd_retrieve_jwks
    title 'JWKS can be retrieved'
    description %(
        Verify that the JWKS can be retrieved from the JWKS uri if it is present in the `jku` field within the JWT token
        header. As per the [CDS hooks specification](https://cds-hooks.hl7.org/2.0#trusting-cds-clients), if the jku
        header field is ommitted, the CDS Client and CDS Service SHALL communicate the JWK Set out-of-band. Therefore,
        if the client does not make their keys publicly available via a uri in the `jku` field, the user must
        submit the jwk_set as an input to the test.
      )

    input :auth_token_header_json
    input :jwk_set,
          title: "The Client's JWK Set containing it's public key",
          description: %(
            Must supply if you do not make your keys publicly available via a uri in the authorization JWT header `jku`
            field'
          ),
          type: 'textarea',
          optional: true
    output :crd_jwks_json, :crd_jwks_keys_json
    makes_request :crd_client_jwks

    run do
      token_header = JSON.parse(auth_token_header_json)
      jku = token_header['jku']

      if jku.present?
        get(jku, name: :crd_client_jwks)

        assert_response_status(200)
        assert_valid_json(response[:body])
        output crd_jwks_json: response[:body]

        jwks = JSON.parse(response[:body])
      else
        skip_if jwk_set.blank?,
                %(JWK Set must be inputted if Client's JWK Set is not available via a URL identified by the jku header
                field)

        jwks = JSON.parse(jwk_set)
      end

      keys = jwks['keys']
      assert keys.is_a?(Array), 'JWKS `keys` field must be an array'

      assert keys.present?, 'The JWK set returned contains no public keys'

      keys.each do |jwk|
        JWT::JWK.import(jwk.deep_symbolize_keys)
      rescue StandardError
        assert false, "Invalid JWK: #{jwk.to_json}"
      end

      kid_presence = keys.all? { |key| key['kid'].present? }
      assert kid_presence, '`kid` field must be present in each key if JWKS contains multiple keys'

      kid_uniqueness = keys.map { |key| key['kid'] }.uniq.length == keys.length
      assert kid_uniqueness, '`kid` must be unique within the client\' JWK Set.'

      output crd_jwks_keys_json: keys.to_json
    end
  end
end
