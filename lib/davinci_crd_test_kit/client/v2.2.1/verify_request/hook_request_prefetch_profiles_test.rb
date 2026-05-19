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
      title 'Prefetched resources conform to the required CRD profiles'
      description %(
        The [CDS service discovery response `prefetch` field](https://cds-hooks.hl7.org/2026Jan/en/#response)
        contains key/value pairs describing additional information needed to render a response. Each key is a
        string that describes the type of data being requested and the corresponding
        value is a FHIR query (read or search) that will return the desired scope.
        See the [Prefetch Template](https://cds-hooks.hl7.org/2026Jan/en/#prefetch-template)
        section for more information about the format of `prefetch` templates.

        [The CRD IG requires client support for prefetch](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#prefetch)
        including that the provided resources, which are part of the data included in the hook invocation,
        [conform to the appropriate CRD profile](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#ci-c-hook-21).

        During this test, Inferno will verify that each FHIR resources found under the `prefetch`
        field of each request body conforms to the appropriate CRD profile.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@hook-21', 'hl7.fhir.us.davinci-crd_2.2.1@prof-3',
                            'hl7.fhir.us.davinci-crd_2.2.1@prof-4', 'hl7.fhir.us.davinci-crd_2.2.1@prof-5',
                            'hl7.fhir.us.davinci-crd_2.2.1@prof-6', 'hl7.fhir.us.davinci-crd_2.2.1@prof-7',
                            'hl7.fhir.us.davinci-crd_2.2.1@prof-8', 'hl7.fhir.us.davinci-crd_2.2.1@prof-9',
                            'hl7.fhir.us.davinci-crd_2.2.1@prof-10', 'hl7.fhir.us.davinci-crd_2.2.1@prof-11',
                            'hl7.fhir.us.davinci-crd_2.2.1@prof-12'
      run do
        hook_requests = load_hook_requests

        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        hook_requests.each_with_index do |request, request_index|
          hook_request = parse_json_request_entity(request.request_body, 'Request body',
                                                   request_index)
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
