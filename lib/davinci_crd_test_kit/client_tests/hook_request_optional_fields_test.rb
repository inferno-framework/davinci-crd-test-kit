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

      This test checks that the optional fields that are present are of the correct type. This test
      will not fail if the hook request does not contain an optional field, it only produces an informational message.
      If the client provides its FHIR server URL in the `fhirServer` field, and it's authorization token in the
      `fhirAuthorization` field object, they will be produced as an output from this test to be used in
      subsequent tests.
    )

    verifies_requirements 'cds-hooks_2.0@1', 'cds-hooks_2.0@3', 'cds-hooks_2.0@20', 'cds-hooks_2.0@21',
                          'cds-hooks_2.0@23', 'cds-hooks_2.0@65', 'cds-hooks_2.0@66', 'cds-hooks_2.0@67',
                          'cds-hooks_2.0@68', 'cds-hooks_2.0@69', 'cds-hooks_2.0@70'

    def hook_name
      config.options[:hook_name]
    end

    output :client_fhir_server
    output :client_access_token,
           optional: true

    run do
      load_tagged_requests(hook_name)
      skip_if requests.empty?, "No #{hook_name} requests were made in a previous test as expected."
      client_fhir_server = nil
      requests.each_with_index do |request, index|
        @request_number = index + 1
        request_body = json_parse(request.request_body)
        if request_body.blank?
          add_message('error', "#{request_number}Hook request body cannot be empty.")
          next
        end

        fhir_server_info = hook_request_optional_fields_check(request_body)
        client_fhir_server ||= fhir_server_info
      end

      unless client_fhir_server.nil?
        output client_fhir_server: client_fhir_server[:fhir_server_uri],
               client_access_token: client_fhir_server[:fhir_access_token]
      end
      no_error_validation('Some service requests contain invalid optional fields.')
    end
  end
end
