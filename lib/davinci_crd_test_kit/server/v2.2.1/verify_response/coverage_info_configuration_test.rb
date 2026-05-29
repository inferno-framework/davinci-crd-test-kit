require_relative '../../../cross_suite/cards_identification'
require_relative '../../server_hook_helper'
require_relative '../server_urls'

module DaVinciCRDTestKit
  module V221
    class CoverageInfoConfigurationTest < Inferno::Test
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::V221::ServerURLs

      title 'Coverage Information configuration option suppresses coverage-info responses'
      id :crd_v221_coverage_info_configuration
      description %(
        This test checks follow-up hook requests made with
        `extension.davinci-crd.configuration.coverage-info` set to `false` after prior successful hook requests
        returned coverage-info content.

        CRD Servers SHALL behave in the manner prescribed by supported configuration information received from
        the CRD Client. When `coverage-info` is `false`, responses must not include coverage-info cards or
        coverage-information/form-completion system actions.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@dev-14',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-28'

      def coverage_info_message(cards, actions)
        card_summaries = cards.map { |card| card['summary'] }.compact
        action_descriptions = actions.map { |action| action['description'] }.compact

        'Coverage-info disabled server response included coverage-info content despite ' \
          "`#{COVERAGE_INFO_CONFIGURATION_CODE}` being set to `false`. " \
          "Cards: #{card_summaries.join(', ')}. System actions: #{action_descriptions.join(', ')}."
      end

      def primary_hook?
        ['appointment-book', 'order-sign', 'order-dispatch'].include? tested_hook_name
      end

      def parsed_body(json)
        JSON.parse(json)
      rescue JSON::ParserError
        nil
      end

      run do
        load_tagged_requests(tested_hook_name, COVERAGE_INFO_DISABLED_TAG)

        if requests.empty?
          message = "No successful #{tested_hook_name} response contained coverage-info content to suppress."
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
              "Coverage-info disabled server request returned HTTP #{request.status}; expected HTTP 200."
            )
            next
          end

          response_body = parsed_body(request.response_body)
          unless response_body.is_a?(Hash)
            add_message('error', 'Coverage-info disabled server response was not valid JSON.')
            next
          end

          cards, actions = coverage_info_content(response_body)
          next if cards.empty? && actions.empty?

          add_message('error', coverage_info_message(cards, actions))
        end

        assert_no_error_messages('Coverage-info configuration responses were not valid. Check messages for details.')
      end
    end
  end
end
