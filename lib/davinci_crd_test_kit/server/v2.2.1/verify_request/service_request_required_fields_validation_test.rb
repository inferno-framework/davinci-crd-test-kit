require_relative '../../server_hook_request_validation'
require_relative '../../server_hook_helper'

module DaVinciCRDTestKit
  module V221
    class ServiceRequestRequiredFieldsValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerHookRequestValidation
      include DaVinciCRDTestKit::ServerHookHelper

      title 'All service requests contain required fields'
      id :crd_v221_service_request_required_fields_validation
      description %(
        During this test, Inferno will verify that each CRD service request generated from the
        tester-provided hook request body input for the active hook group includes the fields required by
        the [CDS Hooks specification section on Calling a CDS Service](https://cds-hooks.hl7.org/2.0/#calling-a-cds-service).

        Required fields include `hook`, `hookInstance`, and `context`. Inferno also verifies the conditional
        presence of `fhirServer` when `fhirAuthorization` is included.
      )
      simulation_verification
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
          hook_request_required_fields_check(request_body, invoked_hook, ig_version: 'v221')
        end

        output contexts: contexts.to_json

        no_error_validation('Some service requests are invalid.')
      end
    end
  end
end
