require_relative '../../server_hook_request_validation'
require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'

module DaVinciCRDTestKit
  module V221
    class ServiceRequestContextValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerHookRequestValidation
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::ServerHookHelper

      title 'Service request contexts are valid'
      id :crd_v221_service_request_context_validation
      description %(
        This test verifies that all service requests `context` field is valid and contains all the
        required fields.
      )
      input :contexts, :invoked_hook

      run do
        parsed_contexts = parse_json(contexts)
        parsed_contexts.each do |context|
          hook_request_context_check(context, invoked_hook, ig_version: 'v221')
        end

        no_error_validation('Some contexts are not valid.')
      end
    end
  end
end
