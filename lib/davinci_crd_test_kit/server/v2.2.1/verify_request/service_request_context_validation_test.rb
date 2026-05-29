require_relative '../../server_hook_request_validation'
require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'

module DaVinciCRDTestKit
  module V221
    class ServiceRequestContextValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerHookRequestValidation
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::ServerHookHelper

      title 'All service requests contain valid context'
      id :crd_v221_service_request_context_validation
      description %(
        During this test, Inferno will verify that each service request `context` field generated from the
        tester-provided hook request body input for the active hook group is valid and contains the required
        fields for the invoked hook.
      )
      simulation_verification
      input :contexts, :invoked_hook

      run do
        parsed_contexts = parse_json(contexts)
        parsed_contexts.each do |context|
          hook_request_context_check(context, invoked_hook, ig_version: 'v221')
        end

        no_error_validation('Some `context` values are invalid.')
      end
    end
  end
end
