require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/response_logical_model_validation'

module DaVinciCRDTestKit
  module V221
    class ProposeAlternateRequestCardValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::ResponseLogicalModelValidation

      title 'Propose Alternate Request cards are valid'
      id :crd_v221_propose_alternate_request_card_validation
      description %(
        This test validates that all [Propose Alternate Request](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#propose-alternate-request)
        cards received are valid. It checks for the presence of a card's suggestion
        with a single action with `Action.type` of `update` or a card with at least
        two actions, one with `Action.type` of `delete` and the other with
        `Action.type` of `create`.
      )
      optional

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-55',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-56'

      input :invoked_hook

      def body_has_no_cards?(body)
        !body.is_a?(Hash) ||
          body['cards'].blank? ||
          !body['cards'].is_a?(Array) ||
          !body['cards'].all?(Hash)
      end

      def alternate_request_cards(request)
        return [] if request.status != 200

        response_body = JSON.parse(request.response_body)

        return [] if body_has_no_cards?(response_body)

        response_body['cards'].select { |card| propose_alternative_request_response_type? card }
      rescue JSON::ParserError
        []
      end

      run do
        load_tagged_requests(tested_hook_name)

        alternate_request_count = 0

        successful_requests = requests.select { |request| request.status == 200 }

        skip_if successful_requests.blank?,
                'No successful hook responses were received'

        requests.each_with_index do |request, index|
          cards = alternate_request_cards(request)

          alternate_request_count += cards.length

          perform_response_logical_model_validation(
            cards,
            nil,
            request.request_body,
            index,
            '2.2.1'
          )
        end

        skip_if alternate_request_count.zero?,
                "#{tested_hook_name} hook responses do not contain any Propose Alternate Request cards."

        no_error_validation('Not all Propose Alternate Request cards were valid. See messages for more information')
      end
    end
  end
end
