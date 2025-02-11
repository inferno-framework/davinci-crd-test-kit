require_relative '../test_helper'
require_relative '../suggestion_actions_validation'
require_relative '../server_hook_helper'

module DaVinciCRDTestKit
  class ProposeAlternateRequestCardValidationTest < Inferno::Test
    include DaVinciCRDTestKit::TestHelper
    include DaVinciCRDTestKit::SuggestionActionsValidation
    include DaVinciCRDTestKit::ServerHookHelper

    title 'Valid Propose Alternate Request cards received'
    id :crd_propose_alternate_request_card_validation
    description %(
      This test validates that all [Propose Alternate Request](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#propose-alternate-request)
      cards received are valid. It checks for the presence of a card's suggestion
      with a single action with `Action.type` of `update` or a card with at least
      two actions, one with `Action.type` of `delete` and the other with
      `Action.type` of `create`.
    )
    optional
    input :valid_cards_with_suggestions, :contexts

    EXPECTED_RESOURCE_TYPES = %w[
      Device DeviceRequest Encounter Medication
      MedicationRequest NutritionOrder ServiceRequest
      VisionPrescription
    ].freeze

    def check_action_type(actions, action_type)
      actions&.any? do |action|
        action['type'] == action_type && action_resource_type_check(action, EXPECTED_RESOURCE_TYPES)
      end
    end

    def propose_alternate_request_card?(card)
      card['suggestions'].any? do |suggestion|
        actions = suggestion['actions']
        has_update = check_action_type(actions, 'update')
        has_delete = check_action_type(actions, 'delete')
        has_create = check_action_type(actions, 'create')

        has_update || (has_delete && has_create)
      end
    end

    run do
      parsed_cards = parse_json(valid_cards_with_suggestions)
      parsed_contexts = parse_json(contexts)
      proposed_alternate_cards = parsed_cards.filter { |card| propose_alternate_request_card?(card) }

      skip_if proposed_alternate_cards.blank?,
              "#{tested_hook_name} hook response does not contain a Propose Alternate Request card."

      proposed_alternate_cards.each do |card|
        card['suggestions'].each do |suggestion|
          actions_check(suggestion['actions'], parsed_contexts)
        end
      end

      no_error_validation('Some Proposed Alternate Request cards are not valid.')
    end
  end
end
