require_relative '../../../cross_suite/cards_identification'
require_relative '../../jwt_helper'
require_relative '../../server_hook_helper'
require_relative '../server_urls'

module DaVinciCRDTestKit
  module V220
    class CoverageInfoConfigurationTest < Inferno::Test
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::V220::ServerURLs

      title 'Coverage information configuration option suppresses coverage-info responses'
      id :crd_v220_coverage_info_configuration
      description %(
        This test repeats prior successful hook requests that returned coverage-info content, with
        `extension.davinci-crd.configuration.coverage-info` set to `false`.

        CRD Servers SHALL behave in the manner prescribed by supported configuration information received from
        the CRD Client. When `coverage-info` is `false`, responses must not include coverage-info cards or
        coverage-information/form-completion system actions.
      )

      input :encryption_method
      input :jwks_kid, optional: true

      def response_body(request)
        JSON.parse(request.response_body)
      rescue JSON::ParserError
        nil
      end

      def response_has_coverage_info?(request)
        body = response_body(request)
        return false unless body.is_a?(Hash)

        cards = body['cards']
        system_actions = body['systemActions']
        (cards.is_a?(Array) && cards.any? { |card| coverage_info_card_type?(card) }) ||
          (system_actions.is_a?(Array) && system_actions.any? { |action| coverage_info_system_action_type?(action) })
      end

      def repeat_request_body(request)
        body = JSON.parse(request.request_body)
        body['hookInstance'] = SecureRandom.uuid
        body['extension'] = {} unless body['extension'].is_a?(Hash)
        unless body['extension']['davinci-crd.configuration'].is_a?(Hash)
          body['extension']['davinci-crd.configuration'] = {}
        end
        body['extension']['davinci-crd.configuration'][COVERAGE_INFO_CONFIGURATION_CODE] = false
        body
      end

      def invocation_headers(service_endpoint)
        token = JwtHelper.build(
          aud: service_endpoint,
          iss: inferno_base_url,
          jku: "#{inferno_base_url}/jwks.json",
          kid: jwks_kid,
          encryption_method:
        )
        { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token}" }
      end

      def repeat_hook_request(request)
        Faraday.post(request.url, repeat_request_body(request).to_json, invocation_headers(request.url))
      end

      def coverage_info_content(response)
        body = JSON.parse(response.body)
        cards = body['cards'].is_a?(Array) ? body['cards'].select { |card| coverage_info_card_type?(card) } : []
        actions =
          if body['systemActions'].is_a?(Array)
            body['systemActions'].select { |action| coverage_info_system_action_type?(action) }
          else
            []
          end

        [cards, actions]
      end

      def coverage_info_message(cards, actions, response_index)
        card_summaries = cards.map { |card| card['summary'] }.compact
        action_descriptions = actions.map { |action| action['description'] }.compact

        "Repeated server response #{response_index + 1} included coverage-info content despite " \
          "`#{COVERAGE_INFO_CONFIGURATION_CODE}` being set to `false`. " \
          "Cards: #{card_summaries.join(', ')}. System actions: #{action_descriptions.join(', ')}."
      end

      run do
        load_tagged_requests(tested_hook_name)
        skip_if requests.blank?, "No #{tested_hook_name} request was made in a previous test as expected."

        repeatable_requests = requests
          .select { |request| request.status == 200 && request.request_body.present? }
          .select { |request| response_has_coverage_info?(request) }

        skip_if repeatable_requests.empty?,
                "No successful #{tested_hook_name} response contained coverage-info content to suppress."

        repeatable_requests.each_with_index do |request, index|
          response = repeat_hook_request(request)
          assert response.status == 200,
                 "Repeated server request #{index + 1} returned HTTP #{response.status}; expected HTTP 200."

          cards, actions = coverage_info_content(response)
          assert cards.empty? && actions.empty?, coverage_info_message(cards, actions, index)
        rescue JSON::ParserError
          assert false, "Repeated server response #{index + 1} was not valid JSON."
        end
      end
    end
  end
end
