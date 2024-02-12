require_relative '../server_hook_request_validation'
require_relative '../test_helper'

module DaVinciCRDTestKit
  class ServiceRequestContextValidationTest < Inferno::Test
    include DaVinciCRDTestKit::ServerHookRequestValidation
    include DaVinciCRDTestKit::TestHelper

    title 'All service requests contain valid context'
    id :crd_service_request_context_validation
    description %(
      This test verifies that all service requests `context` field is valid and contains all the
      required fields.
    )
    input :contexts

    def hook_name
      config.options[:hook_name]
    end

    run do
      parsed_contexts = parse_json(contexts)
      parsed_contexts.each do |context|
        hook_request_context_check(context, hook_name)
      end

      no_error_validation('Some contexts are not valid.')
    end
  end
end
