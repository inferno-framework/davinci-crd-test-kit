module DaVinciCRDTestKit
  class DiscoveryEndpointTest < Inferno::Test
    title 'Server returns a discovery response'
    id :crd_discovery_endpoint_test
    description %(
      A CDS Service provider must expose its discovery endpoint at `{baseURL}/cds-services`
      as specified in the [CDS Hooks Specification](https://cds-hooks.hl7.org/2.0/#discovery).

      This test checks that the server responds to a GET request at the following endpoint:

      `GET {baseURL}/cds-services`

      It does this by checking that the server responds with an HTTP OK 200 status code
      and that the body of the response is a valid JSON object. This test does not
      inspect the structure and content of the response body to see if it contains the required information.
      It only checks to see if the RESTful interaction is supported and returns a valid JSON object.
    )

    input_order :base_url, :authentication_required, :encryption_method, :jwks_kid
    input :base_url
    input :authentication_required,
          title: 'Discovery endpoint requires authentication?',
          type: 'radio',
          default: 'no',
          options: {
            list_options: [
              {
                label: 'No',
                value: 'no'
              },
              {
                label: 'Yes',
                value: 'yes'
              }
            ]
          }
    input :encryption_method,
          title: 'JWT Signing Algorithm',
          description: <<~DESCRIPTION,
            CDS Hooks recommends ES384 and RS384 for JWT signature verification.
            Select which method to use.
          DESCRIPTION
          type: 'radio',
          default: 'ES384',
          options: {
            list_options: [
              {
                label: 'ES384',
                value: 'ES384'
              },
              {
                label: 'RS384',
                value: 'RS384'
              }
            ]
          }
    input :jwks_kid,
          title: 'CDS Services JWKS kid',
          description: <<~DESCRIPTION,
            The key ID of the JWKS private key to use for signing the JWTs when invoking a CDS service endpoint
            requiring authentication.
            Defaults to the first JWK in the list if no kid is supplied.
          DESCRIPTION
          optional: true
    output :cds_services

    run do
      discovery_url = "#{base_url.chomp('/')}/cds-services"
      headers = { 'Accept' => 'application/json' }

      if authentication_required == 'yes'
        token = JwtHelper.build(
          aud: discovery_url,
          iss: inferno_base_url,
          jku: "#{inferno_base_url}/jwks.json",
          kid: jwks_kid,
          encryption_method:
        )
        headers['Authorization'] = "Bearer #{token}"
      end
      get(discovery_url, headers:)
      assert_response_status(200)
      assert_valid_json(request.response_body)

      output cds_services: request.response_body
    end
  end
end
