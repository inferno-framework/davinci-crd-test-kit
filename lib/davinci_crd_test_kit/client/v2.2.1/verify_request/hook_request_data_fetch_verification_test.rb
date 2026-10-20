require_relative '../../../cross_suite/tags'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class HookRequestDataFetchVerificationTest < Inferno::Test
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      id :crd_v221_hook_data_fetch_verification
      title 'CRD client made additional FHIR data available during hook request processing'
      description %(
        During this test, Inferno will verify that for at least one hook request it was successfully
        able to use the FHIR API and access token indicated in that hook request to gather additional data during
        hook invocation. For this test to pass, at least one additional data request across
        all hook invocations must succeed and return a FHIR resource.

        See the [Prefetch and Additional Data Retrieval](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#prefetch-and-additional-data-retrieval)
        section of the CRD Test Kit wiki for details on what requests Inferno will make while processing
        a hook invocation. Note that requests made to a FHIR endpoint other than the `fhirServer`
        indicated in the hook request body do not send the provided access token and do not serve as
        evidence that the CRD client can make FHIR data available for the purposes of this test. To
        pass this test, send hook requests that include references to resources on the CRD client's
        FHIR server within the set that Inferno will fetch as detailed in the wiki.
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
        hook_requests = load_interaction_group_requests

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
               'Inferno was never able to successfully obtain additional FHIR data from the CRD client using the ' \
               'provided access token during hook processing.'
      end
    end
  end
end
