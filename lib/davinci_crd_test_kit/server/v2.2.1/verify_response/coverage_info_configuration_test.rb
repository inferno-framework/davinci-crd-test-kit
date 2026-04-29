require_relative '../../../cross_suite/cards_identification'
require_relative '../../server_hook_helper'
require_relative '../server_urls'

module DaVinciCRDTestKit
  module V221
    class CoverageInfoConfigurationTest < Inferno::Test
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::V221::ServerURLs

      title 'Coverage information configuration option suppresses coverage-info responses'
      id :crd_v221_coverage_info_configuration
      description %(
        This test checks follow-up hook requests made with
        `extension.davinci-crd.configuration.coverage-info` set to `false` after prior successful hook requests
        returned coverage-info content.

        CRD Servers SHALL behave in the manner prescribed by supported configuration information received from
        the CRD Client. When `coverage-info` is `false`, responses must not include coverage-info cards or
        coverage-information/form-completion system actions.
      )

      def coverage_info_message(cards, actions, response_index)
        card_summaries = cards.map { |card| card['summary'] }.compact
        action_descriptions = actions.map { |action| action['description'] }.compact

        "Coverage-info disabled server response #{response_index + 1} included coverage-info content despite " \
          "`#{COVERAGE_INFO_CONFIGURATION_CODE}` being set to `false`. " \
          "Cards: #{card_summaries.join(', ')}. System actions: #{action_descriptions.join(', ')}."
      end

      def parsed_body(json)
        JSON.parse(json)
      rescue JSON::ParserError
        nil
      end

      def coverage_info_disabled_request?(request)
        coverage_info_configuration_disabled?(parsed_body(request.request_body))
      end

      run do
        load_tagged_requests(tested_hook_name)
        skip_if requests.blank?, "No #{tested_hook_name} request was made in a previous test as expected."

        successful_requests = requests.select { |request| request.status == 200 && request.request_body.present? }
        requests_with_coverage_info = successful_requests
          .reject { |request| coverage_info_disabled_request?(request) }
          .select { |request| coverage_info_response?(parsed_body(request.response_body)) }

        skip_if requests_with_coverage_info.empty?,
                "No successful #{tested_hook_name} response contained coverage-info content to suppress."

        coverage_info_disabled_requests = requests
          .select { |request| request.request_body.present? }
          .select { |request| coverage_info_disabled_request?(request) }

        if coverage_info_disabled_requests.empty?
          add_message(
            'error',
            "No #{tested_hook_name} request was made with `#{COVERAGE_INFO_CONFIGURATION_CODE}` set to `false`."
          )
        end

        coverage_info_disabled_requests.each_with_index do |request, index|
          unless request.status == 200
            add_message(
              'error',
              "Coverage-info disabled server request #{index + 1} returned HTTP #{request.status}; expected HTTP 200."
            )
            next
          end

          response_body = parsed_body(request.response_body)
          unless response_body.is_a?(Hash)
            add_message('error', "Coverage-info disabled server response #{index + 1} was not valid JSON.")
            next
          end

          cards, actions = coverage_info_content(response_body)
          next if cards.empty? && actions.empty?

          add_message('error', coverage_info_message(cards, actions, index))
        end

        assert_no_error_messages('Coverage-info configuration responses were not valid. Check messages for details.')
      end
    end
  end
end
