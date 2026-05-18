require_relative '../../multi_request_message_helper'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class HookRequestSecuredTransportTest < Inferno::Test
      include DaVinciCRDTestKit::MultiRequestMessageHelper
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      id :crd_v221_hook_request_secured_transport
      title 'Hook request interactions use TLS'
      description %(
        During this test, Inferno will verify that
        requests made by both the client and Inferno's simulated CRD servers are made against
        TLS-secured endpoints using the `https` protocol.
      )
      verifies_requirements 'cds-hooks_3.0.0-ballot@2', 'cds-hooks_3.0.0-ballot@168', 'cds-hooks_3.0.0-ballot@172',
                            'hl7.fhir.us.davinci-crd_2.2.1@sec-2'

      run do
        hook_requests = load_hook_requests

        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        hook_requests.each_with_index do |request, request_index|
          unless request.url.starts_with?('https')
            add_request_message('error',
                                "Inferno's simulated CRD server must use the https " \
                                'protocol (TLS). Run this suite on a host that uses TLS.',
                                request_index)
          end

          # check that the fhirServer endpoint uses https
          request_body = parse_json_request_entity(request.request_body, 'Request body', request_index)
          next unless request_body.present?
          next unless request_body['fhirServer'].present? && !request_body['fhirServer'].starts_with?('https')

          add_request_message('error',
                              'The `fhirServer` provided in the request must use the https protocol (TLS).',
                              request_index)
        end

        assert_no_error_messages("#{requests_with_errors_prefix}Interactions not secured using TLS. " \
                                 'See Messages for details.')
      end
    end
  end
end
