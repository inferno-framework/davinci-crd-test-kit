require_relative '../../../cross_suite/prefetch_profile_validation'
require_relative '../../tagged_request_load_helper'
require_relative '../../multi_request_message_helper'

module DaVinciCRDTestKit
  module V221
    class HookRequestPrefetchProfilesTest < Inferno::Test
      include PrefetchProfileValidation
      include DaVinciCRDTestKit::TaggedRequestLoadHelper
      include DaVinciCRDTestKit::MultiRequestMessageHelper

      id :crd_v221_hook_request_prefetch_profiles
      title 'Prefetched data conforms to required CRD profiles'
      description %(
        As stated in the [CDS hooks specification](https://build.fhir.org/ig/HL7/cds-hooks/en/#http-request-1),
        a CDS service request's `prefetch` field contains key/value pairs of FHIR queries that the service is
        requesting the CDS Client to perform and provide on each service call. The key is a string that describes
        the type of data being requested and the value is a string representing the FHIR query.
        See [Prefetch Template](https://build.fhir.org/ig/HL7/cds-hooks/en/#prefetch-template)
        for more information about how the `prefetch` formatting works.

        [CRD requires support for prefetch](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#prefetch).
        This test verifies that the incoming hook request's `prefetch` field is present and that the provided
        FHIR resources conform to the appropriate CRD profile.
      )
      # verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@54', 'cds-hooks_2.0@30', 'cds-hooks_2.0@47'

      run do
        hook_requests = load_hook_requests

        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        hook_requests.each_with_index do |request, request_index|
          hook_request = parse_json_request_entity(request.request_body, 'Request body', request_index)
          next unless hook_request.present?
          next unless hook_request.key?('prefetch')

          check_prefetch_profiles(hook_request['prefetch'], request_index)
        end

        assert_no_error_messages("#{requests_with_errors_prefix}Prefetched data not conformant to CRD profiles. " \
                                 'See Messages for details.')
      end
    end
  end
end
