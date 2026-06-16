require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'
require_relative 'hook_request_resource_resolution'

module DaVinciCRDTestKit
  module V221
    class CoverageInformationCardAbsenceTest < Inferno::Test
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification
      include HookRequestResourceResolution

      title 'Hook responses do not include Coverage Information cards'
      id :crd_v221_coverage_information_card_absence
      description %(
        This test verifies that the server does not return the
        [Coverage Information](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type)
        response type as a CDS Hooks card. Coverage Information responses must be returned as `systemActions`
        that update resources with the `coverage-information` extension (inclusion of systemActions is verified in a
        previous test).
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-25'

      input :mock_ehr_bundle, optional: true

      def coverage_information_card_message(response_index, card)
        identifier = card['uuid'].present? ? "uuid `#{card['uuid']}`" : 'no uuid'

        "Server response #{response_index + 1} included a card with #{identifier} and a suggestion action that only " \
          'adds or modifies the coverage-information extension. Coverage Information must be returned as a ' \
          'systemAction, not as a card.'
      end

      def coverage_information_card_response_type?(card, request)
        Array(card['suggestions']).any? do |suggestion|
          Array(suggestion['actions']).any? do |action|
            coverage_information_card_action?(action, request)
          end
        end
      end

      def coverage_information_card_action?(action, request)
        return false unless coverage_information_response_type?(action)
        return false unless action['type'] == 'update'

        source_resource = find_action_source_resource(action, request)
        return coverage_information_extension_only_payload?(action['resource']) unless source_resource

        only_coverage_information_changed?(source_resource.to_hash, action['resource'])
      end

      run do
        load_tagged_requests(tested_hook_name)
        skip_if requests.blank?, "No #{tested_hook_name} request was made in a previous test as expected."

        successful_requests = requests.select { |request| request.status == 200 }
        skip_if successful_requests.empty?, 'All service requests were unsuccessful.'

        successful_requests.each_with_index do |request, index|
          response_body = JSON.parse(request.response_body)
          cards = response_body['cards'].is_a?(Array) ? response_body['cards'] : []

          cards.select { |card| coverage_information_card_response_type?(card, request) }.each do |card|
            add_message('error', coverage_information_card_message(index, card))
          end
        rescue JSON::ParserError
          add_message('error', "Invalid JSON: server response #{index + 1} is not valid JSON.")
        end

        assert_no_error_messages(
          'Service response(s) included Coverage Information cards. Check messages for details.'
        )
      end
    end
  end
end
