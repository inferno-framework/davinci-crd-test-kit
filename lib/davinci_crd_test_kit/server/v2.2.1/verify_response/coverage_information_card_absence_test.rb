require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'

module DaVinciCRDTestKit
  module V221
    class CoverageInformationCardAbsenceTest < Inferno::Test
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification

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

      def coverage_information_card_message(response_index, card)
        summary = card['summary'].present? ? "`#{card['summary']}`" : 'without a summary'

        "Server response #{response_index + 1} included a Coverage Information card #{summary}. " \
          'Coverage Information must be returned as a systemAction, not as a card.'
      end

      run do
        load_tagged_requests(tested_hook_name)
        skip_if requests.blank?, "No #{tested_hook_name} request was made in a previous test as expected."

        successful_requests = requests.select { |request| request.status == 200 }
        skip_if successful_requests.empty?, 'All service requests were unsuccessful.'

        successful_requests.each_with_index do |request, index|
          response_body = JSON.parse(request.response_body)
          cards = response_body['cards'].is_a?(Array) ? response_body['cards'] : []

          cards.select { |card| coverage_info_card_type?(card) }.each do |card|
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
