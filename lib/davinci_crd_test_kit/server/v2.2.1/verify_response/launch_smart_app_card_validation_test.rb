require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/response_logical_model_validation'

module DaVinciCRDTestKit
  module V221
    class LaunchSmartAppCardValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::ResponseLogicalModelValidation

      title 'Launch SMART Application cards are valid'
      id :crd_v221_launch_smart_app_card_validation
      description %(
        This test verifies the presence of valid Launch SMART Application cards
        within the CRD service responses.

        As per the [Da Vinci CRD Implementation
        Guide](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#launch-smart-application-response-type),
        Launch SMART Application cards must contain links with the type set to
        `smart`. This test checks for the presence of any Launch SMART
        Application cards by verifying:
        - The existence of a `links` array within each card.
        - That every link in the `links` array of a card is of type `smart`.

        The test will be skipped if no Launch SMART Application cards are found
        within the returned valid cards.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-72'

      input :invoked_hook

      optional

      def body_has_no_cards?(body)
        !body.is_a?(Hash) ||
          body['cards'].blank? ||
          !body['cards'].is_a?(Array) ||
          !body['cards'].all?(Hash)
      end

      def launch_smart_app_cards(request)
        return [] if request.status != 200

        response_body = JSON.parse(request.response_body)

        return [] if body_has_no_cards?(response_body)

        response_body['cards'].select { |card| launch_smart_app_response_type? card }
      rescue JSON::ParserError
        []
      end

      run do
        load_tagged_requests(tested_hook_name)

        launch_smart_app_count = 0

        successful_requests = requests.select { |request| request.status == 200 }

        skip_if successful_requests.blank?,
                'No successful hook responses were received'

        requests.each_with_index do |request, index|
          cards = launch_smart_app_cards(request)

          launch_smart_app_count += cards.length

          perform_response_logical_model_validation(
            cards,
            nil,
            request.request_body,
            index,
            '2.2.1'
          )
        end

        skip_if launch_smart_app_count.zero?,
                "#{tested_hook_name} hook responses do not contain any Launch SMART App cards."

        no_error_validation('Not all Launch SMART App cards were valid. See messages for more information.')
      end
    end
  end
end
