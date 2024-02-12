module DaVinciCRDTestKit
  class DecodeAuthTokenTest < Inferno::Test
    id :crd_decode_auth_token
    title 'Bearer token can be decoded'
    description %(
        Verify that the Bearer token is a properly constructed JWT. As per the [CDS hooks specification](https://cds-hooks.hl7.org/2.0#trusting-cds-clients),
        each time a CDS Client transmits a request to a CDS Service which requires authentication, the request MUST
        include an Authorization header presenting the JWT as a "Bearer" token.
      )

    output :auth_token, :auth_token_payload_json, :auth_token_header_json

    uses_request :hook_request

    run do
      authorization_header = request.request_header('Authorization')&.value
      skip_if authorization_header.blank?, 'Request does not include an Authorization header'

      assert(authorization_header.start_with?('Bearer '),
             'Authorization token must be a JWT presented as a `Bearer` token')

      auth_token = authorization_header.delete_prefix('Bearer ')
      output(auth_token:)

      begin
        payload, header =
          JWT.decode(
            auth_token,
            nil,
            false
          )

        output auth_token_payload_json: payload.to_json,
               auth_token_header_json: header.to_json
      rescue StandardError => e
        assert false, "Token is not a properly constructed JWT: #{e.message}"
      end
    end
  end
end
