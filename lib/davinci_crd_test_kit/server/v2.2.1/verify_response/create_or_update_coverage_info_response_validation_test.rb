require_relative '../../server_test_helper'
require_relative '../../../cross_suite/suggestion_actions_validation'
require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/cards_validation'

module DaVinciCRDTestKit
  module V221
    class CreateOrUpdateCoverageInfoResponseValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::SuggestionActionsValidation
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::CardsValidation

      title 'Update Coverage Records cards or system actions are valid'
      id :crd_v221_create_or_update_coverage_info_response_validation
      description %(
        This test validates the Update Coverage Records cards or system actions received from the
        CRD service, as per the specifications outlined in the [Da Vinci CRD Implementation Guide](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#update-coverage-records-response-type).

        - **Checking for Presence:**
          The test first checks if any Update Coverage Records cards or system actions are present in
          the returned valid cards or valid system actions.
          - **For cards**: it ensures there are cards with a `suggestions` array containing a single suggestion,
          and the `actions` array of that suggestion has one `create` or `update` action for the `Coverage` resource.
          - **For system actions**: it checks for the presence of `create` or `update` actions for the `Coverage`
          resource.

        - **Validating:**
        If any Update Coverage Records cards or system actions are found, each `Coverage` resource is
        validated against the base FHIR Coverage resource.

        If no Update Coverage Records cards or system actions are received, the test is skipped.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-69',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-71'

      optional
      input :valid_cards_with_suggestions, :valid_system_actions

      run do
        parsed_cards = parse_json(valid_cards_with_suggestions)
        parsed_actions = parse_json(valid_system_actions)

        create_or_update_coverage_info_cards = parsed_cards.select do |card|
          create_or_update_coverage_card_response_type?(card)
        end
        create_or_update_coverage_info_actions = parsed_actions.select do |action|
          create_or_update_coverage_action_response_type?(action)
        end

        skip_msg = "#{tested_hook_name} hook response does not contain any Update Coverage Records " \
                   'cards or system actions.'
        skip_if create_or_update_coverage_info_cards.blank? && create_or_update_coverage_info_actions.blank?, skip_msg

        if create_or_update_coverage_info_actions.present?
          actions_check(create_or_update_coverage_info_actions, ig_version: 'v221')
        end

        if create_or_update_coverage_info_cards.present?
          create_or_update_coverage_info_cards.each do |card|
            actions_check(card['suggestions'].first['actions'].select do |action|
                            create_or_update_coverage_action_response_type?(action)
                          end, ig_version: 'v221')

            create_or_update_coverage_check(card)
          end
        end

        no_error_validation('Some Update Coverage Records received are not valid.')
      end
    end
  end
end
