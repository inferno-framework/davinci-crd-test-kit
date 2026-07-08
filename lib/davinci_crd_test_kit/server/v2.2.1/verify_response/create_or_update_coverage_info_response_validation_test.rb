require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/response_logical_model_validation'

module DaVinciCRDTestKit
  module V221
    class CreateOrUpdateCoverageInfoResponseValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::ResponseLogicalModelValidation

      title 'Create or Update Coverage Information cards and system actions are valid'
      id :crd_v221_create_or_update_coverage_info_response_validation
      description %(
        This test validates the Create or Update Coverage Information cards or
        system actions received from the CRD service, as per the specifications
        outlined in the [Da Vinci CRD Implementation
        Guide](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#update-coverage-records-response-type).

        - **Checking for Presence:**
          The test first checks if any Create or Update Coverage Information
          cards or system actions are present in the returned valid cards or
          valid system actions.
          - **For cards**: it ensures there are cards with a `suggestions` array
            containing a single suggestion, and the `actions` array of that
            suggestion has one `create` or `update` action for the `Coverage`
            resource.
          - **For system actions**: it checks for the presence of `create` or
            `update` actions for the `Coverage` resource.

        - **Validating:**
          If any Create or Update Coverage Information cards or system actions
          are found, each `Coverage` resource is validated against the base FHIR
          Coverage resource.

          If no Create or Update Coverage Information cards or system actions
          are received, the test is skipped.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-3',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-71'

      input :invoked_hook

      optional

      def body_has_no_cards?(body)
        !body.is_a?(Hash) ||
          body['cards'].blank? ||
          !body['cards'].is_a?(Array) ||
          !body['cards'].all?(Hash)
      end

      def update_coverage_cards(request)
        return [] if request.status != 200

        response_body = JSON.parse(request.response_body)

        return [] if body_has_no_cards?(response_body)

        response_body['cards'].select { |card| create_or_update_coverage_card_response_type? card }
      rescue JSON::ParserError
        []
      end

      def body_has_no_system_actions?(body)
        !body.is_a?(Hash) ||
          body['systemActions'].blank? ||
          !body['systemActions'].is_a?(Array) ||
          !body['systemActions'].all?(Hash)
      end

      def update_coverage_actions(request)
        return [] if request.status != 200

        response_body = JSON.parse(request.response_body)

        return [] if body_has_no_system_actions?(response_body)

        response_body['systemActions'].select { |action| create_or_update_coverage_action_response_type? action }
      rescue JSON::ParserError
        []
      end

      run do
        load_tagged_requests(tested_hook_name)

        update_coverage_count = 0

        successful_requests = requests.select { |request| request.status == 200 }

        skip_if successful_requests.blank?,
                'No successful hook responses were received'

        requests.each_with_index do |request, index|
          cards = update_coverage_cards(request)
          actions = update_coverage_actions(request)

          update_coverage_count += cards.length + actions.length

          perform_response_logical_model_validation(
            cards,
            actions,
            request.request_body,
            index,
            '2.2.1'
          )
        end

        skip_if update_coverage_count.zero?,
                "#{tested_hook_name} hook responses do not contain any Update Coverage Records cards or system actions."

        no_error_validation('Not all Update Coverage Records responses were valid. See messages for more information.')
      end
    end
  end
end
