require_relative '../server_hook_request_validation'

module DaVinciCRDTestKit
  class ServiceRequestOptionalFieldsValidationTest < Inferno::Test
    include DaVinciCRDTestKit::ServerHookRequestValidation

    title 'All service requests contain optional fields'
    id :crd_service_request_optional_fields_validation
    description %(
      This optional test reviews the user-submitted CRD service requests for the presence of optional fields:
      `fhirAuthorization` and `prefetch`.

      The test will not fail if these optional fields are missing from a service request; instead, it generates an
      informational message.
    )
    optional

    def hook_name
      config.options[:hook_name]
    end

    run do
      load_tagged_requests(hook_name)
      skip_if requests.empty?, "No #{hook_name} request was made in a previous test as expected."

      requests.each_with_index do |request, index|
        request_body = json_parse(request.request_body, index + 1)
        next unless request_body

        hook_request_optional_fields_check(request_body, index + 1)
      end
      no_error_validation('Some service requests have invalid optional fields.')
    end
  end
end
