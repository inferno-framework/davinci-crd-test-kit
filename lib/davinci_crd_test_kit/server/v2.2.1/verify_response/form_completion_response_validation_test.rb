require_relative '../../server_test_helper'
require_relative '../../../cross_suite/suggestion_actions_validation'
require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/cards_validation'

module DaVinciCRDTestKit
  module V221
    class FormCompletionResponseValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::SuggestionActionsValidation
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::CardsValidation

      title 'Request Form Completion cards and system actions are valid'
      id :crd_v221_request_form_completion_response_validation
      description %(
        This test validates the Request Form Completion cards or system actions received from the CRD service,
        as per the specifications outlined in the [Da Vinci CRD Implementation Guide](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#request-form-completion).

        - **Checking for Presence:**
          The test begins by verifying whether any Request Form Completion cards or system actions are present.
          - **For cards:** It ensures that there are cards with `suggestions` containing `create` actions
          for the `Task` resource, specifically:
            - The `Task` must have a `code` of `complete-questionnaire`.
            - The `Task` should include an input of type `text` (`Task.input.type.text`) labeled as `questionnaire`
            and associated with a valid canonical URL (`Task.input.valueCanonical`).
          - **For system actions:** It checks for the presence of `create` actions for the `Task` resource with
          the characteristics described above.

        - **Validating:**
          If any Request Form Completion cards or system actions are found, the test proceeds to validate them.
          Each `Task` resource is validated against the [CRD Questionnaire Task
          profile](http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-taskquestionnaire).
          Additionally, if any actions for the creation of a `Questionnaire` are
          found, the test verifies that they include the
          `davinci-crd.if-none-exist` extension.

        If no Request Form Completion cards or system actions are received, the test is skipped.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@dev-20',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-62',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-65'

      optional
      input :valid_cards_with_suggestions, :valid_system_actions

      run do
        parsed_cards = parse_json(valid_cards_with_suggestions)
        parsed_actions = parse_json(valid_system_actions)

        form_completion_cards = parsed_cards.select { |card| form_completion_card_response_type?(card) }
        form_completion_actions = parsed_actions.select { |action| form_completion_action_response_type?(action) }

        skip_if form_completion_cards.blank? && form_completion_actions.blank?,
                "#{tested_hook_name} hook response does not contain any Request Form Completion cards " \
                'or system actions.'

        actions_check(form_completion_actions, ig_version: 'v221') if form_completion_actions.present?

        if form_completion_cards.present?
          form_completion_cards.each do |card|
            actions =
              card['suggestions']
                .flat_map { |suggestion| suggestion['actions'] }
                .compact
                .select { |action| form_completion_action_response_type? action }

            actions_check(actions, ig_version: 'v221')

            form_completion_check(card)
          end
        end

        questionnaire_create_actions =
          parsed_actions.select { |action| create_questionnaire_action_response_type?(action) } +
          form_completion_cards
            .flat_map { |card| card['suggestions'] }
            .flat_map { |suggestion| suggestion['actions'] }
            .compact
            .select { |action| create_questionnaire_action_response_type?(action) }

        questionnaire_create_actions.each { |action| questionnaire_creation_check(action) }

        no_error_validation('Some Request Form Completion received are not valid.')
      end
    end
  end
end
