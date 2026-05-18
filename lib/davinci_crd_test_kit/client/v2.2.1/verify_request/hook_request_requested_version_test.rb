require_relative '../../multi_request_message_helper'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class HookRequestRequestedVersionTest < Inferno::Test
      include DaVinciCRDTestKit::MultiRequestMessageHelper
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      id :crd_v221_hook_request_requested_version
      title 'Hook requests contains the CRD version extension'
      description %(
        Inferno's CRD service supports multiple versions of CRD, so [clients are required](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformancedetails.html#ci-c-dev-3)
        to specify the requested version using the `davinci-crd.requestedVersion` extension on each request.

        During this test, Inferno will verify that the body of each hook request contains
        the `davinci-crd.requestedVersion` extension with the correct value: "2.2".
      )

      verifies_requirements 'cds-hooks_3.0.0-ballot@214', 'hl7.fhir.us.davinci-crd_2.2.1@dev-3-A',
                            'hl7.fhir.us.davinci-crd_2.2.1@dev-12'

      run do
        hook_requests = load_hook_requests

        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        hook_requests.each_with_index do |request, request_index|
          request_body = parse_json_request_entity(request.request_body, 'Request body', request_index)
          next unless request_body.present?

          requested_version = request_body.dig('extension', 'davinci-crd.requestedVersion')
          if requested_version.blank?
            add_request_message('error', "Required extension 'davinci-crd.requestedVersion' is not present.",
                                request_index)
          elsif !requested_version.is_a?(String)
            add_request_message('error',
                                "For extension 'davinci-crd.requestedVersion' expected a String, " \
                                "got #{requested_version.class}",
                                request_index)
          elsif requested_version != '2.2'
            add_request_message('error',
                                "For extension 'davinci-crd.requestedVersion' expected '2.2', " \
                                "got '#{requested_version}'",
                                request_index)
          end
        end

        assert_no_error_messages("#{requests_with_errors_prefix}Requested version extension not populated properly. " \
                                 'See Messages for details.')
      end
    end
  end
end
