require_relative '../../../cross_suite/tags'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class HookRequestDataFetchVerificationTest < Inferno::Test
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      id :crd_v221_hook_data_fetch_verification
      title 'Client made additional FHIR data available during hook request processing'
      description %(
        During this test, Inferno will verify that for at least one hook request it was successfully
        able to use the FHIR API and access token indicated in that hook request to gather additional data during
        hook invocation. For this test to pass, at least one additional data request across
        all hook invocations must succeed and return a FHIR resource.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@found-20'

      def fhir_data_returned?(request)
        return false unless request.status.to_s.starts_with?('2')

        fhir_response = FHIR.from_contents(request.response_body)
        return false unless fhir_response.present?

        if fhir_response.is_a?(FHIR::Bundle)
          fhir_response.entry.any? { |entry| entry.resource.present? }
        else
          true
        end
      rescue JSON::ParserError
        false
      end

      run do
        hook_requests = load_hook_requests

        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        data_returned = hook_requests.any? do |request|
          request_body = JSON.parse(request.request_body)
          additional_data_requests =
            load_tagged_requests(TagMethods.hook_instance_data_fetch_tag(request_body['hookInstance']), DATA_FETCH_TAG)

          additional_data_requests.any? { |data_request| fhir_data_returned?(data_request) }
        rescue JSON::ParserError
          false
        end

        assert data_returned,
               'Inferno was never able to successfully obtain additional FHIR data during hook processing.'
      end
    end
  end
end
