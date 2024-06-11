require_relative '../client_hook_request_validation'

module DaVinciCRDTestKit
  class HookRequestOptionalFieldsTest < Inferno::Test
    include ClientHookRequestValidation
    include URLs

    id :crd_hook_request_optional_fields
    title 'Hook request contains optional fields'
    description %(
      Under the [CDS hooks HTTP Request section](https://cds-hooks.hl7.org/2.0/#http-request_1), the specification
      requires that a CDS service request SHALL include a JSON POST body which MAY contain the following optional input
      fields:
        * `fhirServer` - *URL*
        * `fhirAuthorization` - *object*
        * `prefetch` - *object*

      This test checks for the precense of these fields and if they are of the correct type. This test is optional and
      will not fail if the hook request does not contain an optional field, it only produces an informational message.
      If the client provides its FHIR server URL in the `fhirServer` field, and it's authorization token in the
      `fhirAuthorization` field object, they will be produced as an output from this test to be used in
      subsequent tests.
    )
    optional

    def hook_name
      config.options[:hook_name]
    end

    output :client_fhir_server
    output :client_access_token,
           optional: true

    run do
      load_tagged_requests(hook_name)
      skip_if requests.empty?, "No #{hook_name} requests were made in a previous test as expected."
      error_messages = []
      client_fhir_server = nil
      requests.each_with_index do |request, index|
        assert_valid_json(request.request_body)
        request_body = JSON.parse(request.request_body)
        fhir_server_info = hook_request_optional_fields_check(request_body, index + 1)
        client_fhir_server ||= fhir_server_info
      rescue Inferno::Exceptions::AssertionException => e
        error_messages << "Request #{index + 1}: #{e.message}"
      end

      unless client_fhir_server.nil?
        output client_fhir_server: client_fhir_server[:fhir_server_uri],
               client_access_token: client_fhir_server[:fhir_access_token]
      end

      error_messages.each do |msg|
        add_message('error', msg)
      end
      no_error_validation('Some service requests contain invalid optional fields.')
    end
  end
end
