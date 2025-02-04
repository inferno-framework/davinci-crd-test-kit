require_relative '../server_hook_request_validation'
require_relative '../server_hook_helper'

module DaVinciCRDTestKit
  class ServiceRequestRequiredFieldsValidationTest < Inferno::Test
    include DaVinciCRDTestKit::ServerHookRequestValidation
    include DaVinciCRDTestKit::ServerHookHelper

    title 'All service requests contain required fields'
    id :crd_service_request_required_fields_validation
    description %(
      This test validates all CRD service requests provided by the user, ensuring each includes all required fields
      specified in the [CDS Hooks spec section on Calling a CDS Service](https://cds-hooks.hl7.org/2.0/#calling-a-cds-service):
      `hook`, `hookInstance`, and `context`. Furthermore, the test checks for the conditional presence of the
      `fhirServer` field if `fhirAuthorization` is included.
    )
    input :invoked_hook
    output :contexts

    run do
      load_tagged_requests(tested_hook_name)
      skip_if requests.empty?, "No #{tested_hook_name} request was made in a previous test as expected."
      contexts = []
      requests.each_with_index do |request, index|
        @request_number = index + 1
        request_body = json_parse(request.request_body)
        next if request_body.blank?

        contexts << request_body['context'] if request_body['context'].is_a?(Hash)
        hook_request_required_fields_check(request_body, invoked_hook)
      end

      output contexts: contexts.to_json

      no_error_validation('Some service requests made are not valid.')
    end
  end
end
