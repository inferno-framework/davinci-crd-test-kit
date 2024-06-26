require_relative '../client_hook_request_validation'

module DaVinciCRDTestKit
  class HookRequestRequiredFieldsTest < Inferno::Test
    include ClientHookRequestValidation
    include URLs

    id :crd_hook_request_required_fields
    title 'Hook request contains required fields'
    description %(
      Under the [CDS hooks HTTP Request section](https://cds-hooks.hl7.org/2.0/#http-request_1), the specification
      requires that a CDS service request SHALL include a JSON POST body with the following input fields:
        * `hook` - *string*
        * `hookInstance` - *string*
        * `context` - *object*

        Additionally, if the optional `fhirAuthorization` field is present, then the `fhirServer` field is required.

        This test also checks that the `hook` field contains the correct CDS service name that the CDS client is sending
        a request for
    )

    def hook_name
      config.options[:hook_name]
    end

    output :contexts, :prefetches

    run do
      load_tagged_requests(hook_name)
      skip_if requests.empty?, "No #{hook_name} requests were made in a previous test as expected."
      contexts = []
      prefetches = []
      requests.each_with_index do |request, index|
        @request_number = index + 1
        request_body = json_parse(request.request_body)
        next if request_body.blank?

        contexts << request_body['context'] if request_body['context'].is_a?(Hash)
        prefetches << request_body['prefetch'] if request_body['prefetch'].is_a?(Hash)
        hook_request_required_fields_check(request_body, hook_name)
      end

      output contexts: contexts.to_json,
             prefetches: prefetches.to_json
      no_error_validation('Some service requests made are not valid.')
    end
  end
end
