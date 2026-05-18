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
        This test checks follow-up hook requests made with a random CDS Hooks
        element set to a random value after prior successful hook requests
        returned coverage-info content to verify that servers ignore unknown CDS
        Hooks elements.
      )

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
            add_message('error', 'Unknown CDS Hooks element server response was not valid JSON.')
            next
          end

          next if coverage_info_response?(response_body)

          add_message(
            'error',
            'Request with unknown CDS Hooks element did not receive a coverage information response.'
          )
        end

        assert_no_error_messages(
          'Responses to requests with unknown CDS Hooks element were not valid. Check messages for details.'
        )
      end
    end
  end
end
