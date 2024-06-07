require_relative '../client_hook_request_validation'

module DaVinciCRDTestKit
  class HookRequestRequiredFieldsTest < Inferno::Test
    include DaVinciCRDTestKit::ClientHookRequestValidation
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

    output :contexts_prefetches

    run do
      load_tagged_requests(hook_name)
      skip_if requests.empty?, "No #{hook_name} requests were made in a previous test as expected."
      error_messages = []
      contexts_prefetches = []
      requests.each_with_index do |request, index|
        assert_valid_json(request.request_body)
        request_body = JSON.parse(request.request_body)
        context = request_body['context'] if request_body['context'].is_a?(Hash)
        prefetch = request_body['prefetch'] if request_body['prefetch'].present? &&
                                               request_body['prefetch'].is_a?(Hash)
        contexts_prefetches << { context:, prefetch: }
        hook_request_required_fields_check(request_body, hook_name)
      rescue Inferno::Exceptions::AssertionException => e
        error_messages << "Request #{index + 1}: #{e.message}"
      end

      output contexts_prefetches: contexts_prefetches.to_json

      error_messages.each do |msg|
        messages << { type: 'error', message: msg }
      end
      assert error_messages.empty?, 'Some service requests made are not valid.'
    end
  end
end
