require_relative '../../../cross_suite/non_must_support_check'
require_relative '../../tagged_request_load_helper'
require_relative '../../multi_request_message_helper'

module DaVinciCRDTestKit
  module V221
    class HookRequestNoNonMustSupportTest < Inferno::Test
      include DaVinciCRDTestKit::NonMustSupportCheck
      include DaVinciCRDTestKit::TaggedRequestLoadHelper
      include DaVinciCRDTestKit::MultiRequestMessageHelper

      id :crd_v221_hook_request_no_non_ms
      title 'Client hook requests contain no non-must-support elements'
      description %(
        Da Vinci Burden Reduction guides require that conforming clients SHALL NOT
        depend on non-must-support elements
        ([CRD conf-10](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-10),
        [CRD conf-13](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-13)).
        We verify this by ensuring no non-must-support element of the applicable CRD
        profile is populated in the prefetched resources sent with the hook request.

        Inferno walks each FHIR resource found under the `prefetch` field of every
        captured hook request and reports any non-must-support element paths or
        extension URLs that are present.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-10',
                            'hl7.fhir.us.davinci-crd_2.2.1@conf-13'

      run do
        hook_requests = load_hook_requests

        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        hook_requests.each_with_index do |request, request_index|
          hook_request = parse_json_request_entity(request.request_body, 'Request body',
                                                   request_index)
          next unless hook_request.present?
          next unless hook_request.key?('prefetch')

          check_hook_request_non_must_support(hook_request['prefetch'], request_index)
        end

        assert_no_error_messages(
          "#{requests_with_errors_prefix}Hook request resources contained non-must-support elements. " \
          'See Messages for details.'
        )
      end
    end
  end
end
