require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/response_logical_model_validation'

module DaVinciCRDTestKit
  module V221
    class FormCompletionResponseValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::ResponseLogicalModelValidation

      title 'Request Form Completion cards and system actions are valid'
      id :crd_v221_request_form_completion_response_validation
      description %(
        This test validates the Request Form Completion cards or system actions
        received from the CRD service, as per the specifications outlined in the
        [Da Vinci CRD Implementation
        Guide](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#request-form-completion-response-type).

        - **Checking for Presence:**
          The test begins by verifying whether any Request Form Completion cards
          or system actions are present.
          - **For cards:** It ensures that there are cards with `suggestions`
            containing `create` actions for the `Task` resource, specifically:
            - The `Task` must have a `code` of `complete-questionnaire`.
            - The `Task` should include an input of type `text`
              (`Task.input.type.text`) labeled as `questionnaire` and associated
              with a valid canonical URL (`Task.input.valueCanonical`).
          - **For system actions:** It checks for the presence of `create`
            actions for the `Task` resource with the characteristics described
            above.

        - **Validating:**
          If any Request Form Completion cards or system actions are found, the
          test proceeds to validate them. Each `Task` resource is validated
          against the [CRD Questionnaire Task
          profile](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-taskquestionnaire.html).
          Additionally, if any actions for the creation of a `Questionnaire` are
          found, the test verifies that they include the
          `davinci-crd.if-none-exist` extension.

        If no Request Form Completion cards or system actions are received, the test is skipped.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@dev-20',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-3',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-62',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-65'

      input :invoked_hook

      optional

      def body_has_no_cards?(body)
        !body.is_a?(Hash) ||
          body['cards'].blank? ||
          !body['cards'].is_a?(Array) ||
          !body['cards'].all?(Hash)
      end

      def form_completion_cards(request)
        return [] if request.status != 200

        response_body = JSON.parse(request.response_body)

        return [] if body_has_no_cards?(response_body)

        response_body['cards'].select { |card| form_completion_card_response_type? card }
      rescue JSON::ParserError
        []
      end

      def body_has_no_system_actions?(body)
        !body.is_a?(Hash) ||
          body['systemActions'].blank? ||
          !body['systemActions'].is_a?(Array) ||
          !body['systemActions'].all?(Hash)
      end

      def form_completion_actions(request)
        return [] if request.status != 200

        response_body = JSON.parse(request.response_body)

        return [] if body_has_no_system_actions?(response_body)

        response_body['systemActions'].select { |action| form_completion_action_response_type? action }
      rescue JSON::ParserError
        []
      end

      run do
        load_tagged_requests(tested_hook_name)

        form_completion_count = 0

        successful_requests = requests.select { |request| request.status == 200 }

        skip_if successful_requests.blank?,
                'No successful hook responses were received'

        requests.each_with_index do |request, index|
          cards = form_completion_cards(request)
          actions = form_completion_actions(request)

          form_completion_count += cards.length + actions.length

          perform_response_logical_model_validation(
            cards,
            actions,
            request.request_body,
            index,
            '2.2.1'
          )
        end

        skip_if form_completion_count.zero?,
                "#{tested_hook_name} hook responses do not contain any Request Form Completion cards or system actions."

        no_error_validation('Not all Request Form Completion responses were valid. See messages for more information.')
      end
    end
  end
end
