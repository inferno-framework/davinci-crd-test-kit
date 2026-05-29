require_relative '../../server_test_helper'
require_relative '../../../cross_suite/suggestion_actions_validation'
require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/cards_validation'

module DaVinciCRDTestKit
  module V221
    class ProposeAlternateRequestCardValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::SuggestionActionsValidation
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::CardsValidation

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

      input :valid_cards_with_suggestions, :contexts

      run do
        parsed_cards = parse_json(valid_cards_with_suggestions)
        parsed_contexts = parse_json(contexts)
        proposed_alternate_cards = parsed_cards.filter do |card|
          propose_alternative_request_response_type?(card)
        end

        skip_if proposed_alternate_cards.blank?,
                "#{tested_hook_name} hook response does not contain a Propose Alternate Request card."

        proposed_alternate_cards.each do |card|
          card['suggestions'].each do |suggestion|
            actions_check(suggestion['actions'], parsed_contexts, ig_version: 'v221')
          end

          propose_alternate_request_check(card)
        end

        no_error_validation('Some Propose Alternate Request cards are not valid.')
      end
    end
  end
end
