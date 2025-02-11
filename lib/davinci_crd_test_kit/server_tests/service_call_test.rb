require_relative '../server_hook_helper'
require_relative '../tags'

module DaVinciCRDTestKit
  class ServiceCallTest < Inferno::Test
    include ServerHookHelper

    title 'Submit user-defined service requests'
    id :crd_service_call_test
    description %(
      This test initiates POST request(s) to a specified CDS Service using the JSON body list provided by the user.
      As indicated in the [CDS Hooks specification section on Calling a CDS Service](https://cds-hooks.hl7.org/2.0/#calling-a-cds-service),
      the service endpoint is constructed by appending the individual service id to the CDS Service base URL,
      following the format `{baseUrl}/cds-services/{service.id}`.

      If running this group only, the user will need to provide the `service.id` to call the specified service.
      Otherwise, the `service.id` is derived from the CDS Services that are retrieved through a query to the
      discovery endpoint.

      The test will be skipped if the CRD server does not host a CDS Service corresponding to the hook that
      is being tested.

      The test is deemed successful if the CRD server returns a 200 HTTP response for all requests.
    )
    input_order :base_url, :encryption_method, :jwks_kid
    input :base_url
    input :service_ids,
          description: %(
            If blank, Inferno will attempt to infer the service id to use by finding a service entry in the
            Discovery response for the target hook. If it cannot be inferred, the tests will be skipped.
          ),
          optional: true
    input :service_request_bodies,
          optional: true,
          type: 'textarea',
          description: 'To send multiple requests, provide as a JSON list, e.g., [json_body_1, json_body_2].'
    input :encryption_method,
          title: 'JWT Signing Algorithm',
          description: <<~DESCRIPTION,
            CDS Hooks recommends ES384 and RS384 for JWT signature verification.
            Select which method to use.
          DESCRIPTION
          type: 'radio',
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
    output :invoked_hook

    run do
      discovery_url = "#{base_url.chomp('/')}/cds-services"
      skip_if service_request_bodies.blank?,
              'Request body not provided, skipping test.'
      assert_valid_json(service_request_bodies)

      payloads = [JSON.parse(service_request_bodies)].flatten
      skip_if tested_hook_name == ANY_HOOK_TAG && payloads.length != 1,
              'The *Demonstrate a Hook Invocation* test supports only one request body.'
      invoked_hook = identify_hook(payloads)
      service_id = target_service_id(service_ids, invoked_hook)
      skip_if service_id.blank?, "No service id provided or discovered for the #{invoked_hook} hook"

      service_endpoint = "#{discovery_url}/#{service_id}"
      token = JwtHelper.build(
        aud: service_endpoint,
        iss: inferno_base_url,
        jku: "#{inferno_base_url}/jwks.json",
        kid: jwks_kid,
        encryption_method:
      )
      headers = { 'Content-type' => 'application/json', 'Authorization' => "Bearer #{token}" }

      payloads.each do |payload|
        post(service_endpoint, body: payload.to_json, headers:, tags: [tested_hook_name])
      end

      output(invoked_hook:)

      requests.each do |request|
        assert_response_status(200, request:)
        assert_valid_json(request.response_body)
      end
    end
  end
end
