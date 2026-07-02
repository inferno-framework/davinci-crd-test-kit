require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/hook_request_field_validation'
require_relative '../../../cross_suite/requests_logical_model_validation'

module DaVinciCRDTestKit
  module V221
    class ServiceRequestRequiredFieldsValidationTest < Inferno::Test
      include HookRequestFieldValidation
      include RequestsLogicalModelValidation
      include DaVinciCRDTestKit::ServerHookHelper

      title 'Service requests contain required fields'
      id :crd_v221_service_request_required_fields_validation
      description %(
        During this test, Inferno will check each request body against the structural and content
        requirements for the invoked hook.
      )
      input :invoked_hook, :unknown_context_key, :unknown_element_key
      output :contexts

      run do
        load_tagged_requests(tested_hook_name)

        skip_if requests.empty?, "No #{tested_hook_name} request was made in a previous test as expected."

        requests.each_with_index do |request, index|
          request_body = JSON.parse(request.request_body)
          next if request_body.blank?

          validate_request_against_logical_model(request_body, index, '2.2.1')
        rescue JSON::ParserError
          add_message('error', "Invalid JSON: server response #{index + 1} is not valid JSON.")
        end

        messages.reject! do |message|
          message[:message].match?(/Unrecognized property '#{unknown_context_key}'/) ||
            message[:message].match?(/Unrecognized property '#{unknown_element_key}'/)
        end

        no_error_validation('Some service requests made are not valid.')
      end
    end
  end
end
