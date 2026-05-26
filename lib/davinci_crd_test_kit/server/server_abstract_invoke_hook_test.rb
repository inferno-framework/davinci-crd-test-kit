require_relative 'server_hook_helper'
require_relative '../cross_suite/tags'
require_relative 'jobs/invoke_hook'

module DaVinciCRDTestKit
  class ServerAbstractInvokeHookTest < Inferno::Test
    include ServerHookHelper

    # must include the corresponding server_urls class when using in a suite

    title 'Invoke Hook'
    id :crd_server_invoke_hook_test
    description %(
        This test initiates POST request(s) to a specified CDS Service using the JSON body list provided by the user.
        As indicated in the [CDS Hooks specification section on Calling a CDS Service](https://cds-hooks.hl7.org/2.0/#calling-a-cds-service),
        the service endpoint is constructed by appending the individual service id to the CDS Service base URL,
        following the format `{baseUrl}/cds-services/{service.id}`. While the requests are being made,
        Inferno will enable FHIR endpoints that serve the data indicated in the Mock EHR Bundle so that the
        tested server can access additional information not provided in the hook request.

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
    input :mock_ehr_bundle,
          title: 'Mock EHR Data',
          description: <<~DESCRIPTION,
            A FHIR Bundle containing resources that Inferno will make available via the FHIR API hosted
            by its simulated CRD client that will initiate the CDS Hooks requests.
          DESCRIPTION
          type: 'textarea',
          optional: true,
          default: '{"resourceType":"Bundle","type":"collection"}'
    input :manual_continuation,
          title: 'Require acknowledgement of completed hook requests?',
          description: %(
              By default, Inferno will continue evaluation of the hook response(s) immediately after completing
              the request(s). To keep Inferno's simulated CRD Client and its FHIR endpoints active longer,
              select the "Continue on user acknowledgement" option and you will be asked to click a link when
              you are ready for Inferno to continue.
            ),
          type: 'radio',
          default: 'no',
          options: {
            list_options: [
              {
                label: 'Continue when hook invocation(s) complete',
                value: 'no'
              }, {
                label: 'Continue on user acknowledgement',
                value: 'yes'
              }
            ]
          },
          optional: true

    output :invoked_hook
    output :continuation_url

    run do
      discovery_url = "#{base_url.chomp('/')}/cds-services"

      begin
        bundle_resource = FHIR.from_contents(mock_ehr_bundle)
      rescue StandardError
        bundle_resource = nil
      end
      skip_if !bundle_resource.is_a?(FHIR::Bundle),
              'mock_ehr_bundle input must be a FHIR Bundle resource; skipping test.'

      skip_if service_request_bodies.blank?,
              'Request body not provided, skipping test.'
      assert_valid_json(service_request_bodies)

      payloads = [JSON.parse(service_request_bodies)].flatten
      skip_if tested_hook_name == ANY_HOOK_TAG && payloads.length != 1,
              'The *Demonstrate a Hook Invocation* test supports only one request body.'
      invoked_hook = identify_hook(payloads)
      output(invoked_hook:)
      service_id = target_service_id(service_ids, invoked_hook)
      skip_if service_id.blank?, "No service id provided or discovered for the #{invoked_hook} hook"

      service_endpoint = "#{discovery_url}/#{service_id}"
      continuation_url = "#{resume_pass_url}?token=#{test_session_id}"
      output(continuation_url:)
      failure_url = "#{resume_fail_url}?token=#{test_session_id}"

      acknowledge_before_continuing = manual_continuation == 'yes'
      Inferno::Jobs.perform(DaVinciCRDTestKit::Jobs::InvokeHook, test_session_id,
                            payloads, service_endpoint, inferno_base_url, jwks_kid, encryption_method,
                            tested_hook_name, continuation_url, failure_url, acknowledge_before_continuing,
                            coverage_info_configuration_supported?)

      wait(
        identifier: test_session_id,
        timeout: acknowledge_before_continuing ? 900 : 300,
        message: wait_message(acknowledge_before_continuing, continuation_url)
      )
    end

    def wait_message(acknowledge_before_continuing, continuation_url)
      message = "Inferno's simulated CRD Client will initiate hook requests to the server. " \
                'During these invocations the server will be able to make FHIR requests ' \
                "against Inferno's simulated CRD Client."

      return message unless acknowledge_before_continuing

      "#{message}\n\n#{continuation_message(continuation_url)}"
    end

    def continuation_message(continuation_url)
      'Once all hook requests have been made and the server has gathered all desired information ' \
        "from the FHIR server of Inferno's simulated CRD Client, [click here](#{continuation_url}) " \
        'to continue the tests.'
    end

    def coverage_info_configuration_supported?
      false
    end
  end
end
