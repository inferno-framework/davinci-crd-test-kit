require_relative '../../server_hook_request_validation'
require_relative '../../server_hook_helper'

module DaVinciCRDTestKit
  module V221
    class ServiceRequestOptionalFieldsValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerHookRequestValidation
      include DaVinciCRDTestKit::ServerHookHelper

      title 'All service requests contain optional fields'
      id :crd_v221_service_request_optional_fields_validation
      description %(
        During this test, Inferno will verify optional fields in the CRD service requests generated from the
        tester-provided hook request body input for the active hook group when those fields are present.

        Optional fields include:
        `fhirAuthorization` and `prefetch`.

        Inferno does not fail the test if these optional fields are missing from a service request; instead,
        it generates an informational message.
      )
      simulation_verification
      optional

      run do
        load_tagged_requests(tested_hook_name)
        skip_if requests.empty?, "No #{tested_hook_name} request was made in a previous test as expected."

        requests.each_with_index do |request, index|
          @request_number = index + 1
          request_body = json_parse(request.request_body)
          if request_body.blank?
            add_message('error', "#{request_number}Hook request body cannot be empty.")
            next
          end

          hook_request_optional_fields_check(request_body, ig_version: 'v221')
        end
        no_error_validation('Some service requests have invalid optional fields.')
      end
    end
  end
end
