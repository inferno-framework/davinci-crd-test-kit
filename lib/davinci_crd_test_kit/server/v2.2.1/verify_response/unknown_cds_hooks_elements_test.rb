require_relative '../../../cross_suite/cards_identification'
require_relative '../../server_hook_helper'
require_relative '../server_urls'

module DaVinciCRDTestKit
  module V221
    class UnknownCDSHooksElementsTest < Inferno::Test
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::V221::ServerURLs

      title 'Server ignores unknown CDS Hooks elements'
      id :crd_v221_unknown_cds_hooks_elements
      description %(
        If a request resulted in a successful response with a coverage
        information system action, a follow-up request is made with an element
        with a random key and value added to the CDS hooks request. This test
        verifes that this follow-up request also resulted in a successful
        response with a coverage information system action to verify that
        unknown CDS Hooks elements are ignored.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@found-33'

      def primary_hook?
        ['appointment-book', 'order-sign', 'order-dispatch'].include? tested_hook_name
      end

      def parsed_body(json)
        JSON.parse(json)
      rescue JSON::ParserError
        nil
      end

      run do
        load_tagged_requests(tested_hook_name, UNKNOWN_ELEMENT_TAG)

        if requests.empty?
          message = "No successful #{tested_hook_name} response contained a coverage-info action."
          if primary_hook?
            skip message
          else
            omit message
          end
        end

        requests.each do |request|
          unless request.status == 200
            add_message(
              'error',
              "Server request returned HTTP #{request.status} for a request with an unknown CDS Hooks element; " \
              'expected HTTP 200.'
            )
            next
          end

          response_body = parsed_body(request.response_body)
          unless response_body.is_a?(Hash)
            add_message('error', 'Server response to a request with an unknown CDS Hooks element was not valid JSON.')
            next
          end

          next if coverage_info_system_action_response?(response_body)

          add_message(
            'error',
            'Server response to a request with an unknown CDS Hooks element did not contain ' \
            'a coverage information system action.'
          )
        end

        assert_no_error_messages(
          'Responses to requests with an unknown CDS Hooks element were not valid. Check messages for details.'
        )
      end
    end
  end
end
