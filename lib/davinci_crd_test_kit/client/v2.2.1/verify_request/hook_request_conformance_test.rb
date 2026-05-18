require_relative '../../../cross_suite/requests_logical_model_validation'
require_relative '../../tagged_request_load_helper'
require_relative '../../multi_request_message_helper'

module DaVinciCRDTestKit
  module V221
    class HookRequestConformanceTest < Inferno::Test
      include RequestsLogicalModelValidation
      include DaVinciCRDTestKit::TaggedRequestLoadHelper
      include DaVinciCRDTestKit::MultiRequestMessageHelper

      id :crd_v221_hook_request_conformance
      title 'Hook requests have the correct structure and contents'
      description %(
        During this test, Inferno will check each request body against the structural and content
        requirements for the invoked hook.
      )

      output :url, :smart_auth_info

      verifies_requirements 'cds-hooks_3.0.0-ballot@3', 'cds-hooks_3.0.0-ballot@222', 'cds-hooks_3.0.0-ballot@223',
                            'cds-hooks_3.0.0-ballot@224',
                            'hl7.fhir.us.davinci-crd_2.2.1@billopt-1', 'hl7.fhir.us.davinci-crd_2.2.1@found-36-A',
                            'hl7.fhir.us.davinci-crd_2.2.1@hook-20', 'hl7.fhir.us.davinci-crd_2.2.1@hook-21'

      run do
        hook_requests = load_hook_requests

        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        hook_requests.each_with_index do |request, request_index|
          request_body = parse_json_request_entity(request.request_body, 'Request body', request_index)
          next unless request_body.present?

          validate_request_against_logical_model(request_body, request_index, '2.2.1')

          output url: request_body['fhirServer'] if request_body['fhirServer'].present?
          if request_body.dig('fhirAuthorization', 'access_token').present?
            output smart_auth_info: { access_token: request_body['fhirAuthorization']['access_token'] }.to_json
          end
        end

        assert_no_error_messages("#{requests_with_errors_prefix}Non-conformant hook request. See Messages for details.")
      end
    end
  end
end
