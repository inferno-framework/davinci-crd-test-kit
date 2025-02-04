require_relative '../test_helper'
require_relative '../suggestion_actions_validation'
require_relative '../server_hook_helper'

module DaVinciCRDTestKit
  class CreateOrUpdateCoverageInfoResponseValidationTest < Inferno::Test
    include DaVinciCRDTestKit::TestHelper
    include DaVinciCRDTestKit::SuggestionActionsValidation
    include DaVinciCRDTestKit::ServerHookHelper

    title 'Valid Create or Update Coverage Information cards or system actions received'
    id :crd_create_or_update_coverage_info_response_validation
    description %(
      This test validates the Create or Update Coverage Information cards or system actions received from the
      CRD service, as per the specifications outlined in the [Da Vinci CRD Implementation Guide](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#create-or-update-coverage-information).

      - **Checking for Presence:**
        The test first checks if any Create or Update Coverage Information cards or system actions are present in
        the returned valid cards or valid system actions.
        - **For cards**: it ensures there are cards with a `suggestions` array containing a single suggestion,
        and the `actions` array of that suggestion has one `create` or `update` action for the `Coverage` resource.
        - **For system actions**: it checks for the presence of `create` or `update` actions for the `Coverage`
        resource.

      - **Validating:**
      If any Create or Update Coverage Information cards or system actions are found, each `Coverage` resource is
      validated against the base FHIR Coverage resource.

      If no Create or Update Coverage Information cards or system actions are received, the test is skipped.
    )
    optional
    input :valid_cards_with_suggestions, :valid_system_actions

    def coverage_actions(actions)
      return [] if actions.nil?

      valid_types = ['create', 'update']
      actions.filter do |action|
        valid_types.include?(action['type']) && action_resource_type_check(action, ['Coverage'])
      end
    end

    def create_or_update_coverage_info_card?(card)
      card['suggestions'].one? && coverage_actions(card['suggestions'].first['actions']).one?
    end

    run do
      parsed_cards = parse_json(valid_cards_with_suggestions)
      parsed_actions = parse_json(valid_system_actions)

      create_or_update_coverage_info_cards = parsed_cards.filter { |card| create_or_update_coverage_info_card?(card) }
      create_or_update_coverage_info_actions = coverage_actions(parsed_actions)

      skip_msg = "#{tested_hook_name} hook response does not contain any Create or Update Coverage Information " \
                 'cards or system actions.'
      skip_if create_or_update_coverage_info_cards.blank? && create_or_update_coverage_info_actions.blank?, skip_msg

      actions_check(create_or_update_coverage_info_actions) if create_or_update_coverage_info_actions.present?

      if create_or_update_coverage_info_cards.present?
        create_or_update_coverage_info_cards.each do |card|
          actions = card['suggestions'].first['actions']
          actions_check(coverage_actions(actions))
        end
      end

      no_error_validation('Some Create or Update Coverage Information received are not valid.')
    end
  end
end
