require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/response_logical_model_validation'

module DaVinciCRDTestKit
  module V221
    class InstructionsCardReceivedTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::ResponseLogicalModelValidation

      title 'Instructions cards are valid'
      id :crd_v221_valid_instructions_card_received
      description %(
        This test validates that an
        [Instructions](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#instructions-response-type)
        card was received. It does so by:
        - Checking for the presence of a valid card that does not contain the
          `links` field and the `suggestions` field.

        The test will be skipped if no Instructions cards are found within the
        returned valid cards.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-24'

      input :invoked_hook

      optional

      def body_has_no_cards?(body)
        !body.is_a?(Hash) ||
          body['cards'].blank? ||
          !body['cards'].is_a?(Array) ||
          !body['cards'].all?(Hash)
      end

      def instructions_cards(request)
        return [] if request.status != 200

        response_body = JSON.parse(request.response_body)

        return [] if body_has_no_cards?(response_body)

        response_body['cards'].select { |card| instructions_response_type? card }
      rescue JSON::ParserError
        []
      end

      run do
        load_tagged_requests(tested_hook_name)

        instructions_count = 0

        successful_requests = requests.select { |request| request.status == 200 }

        skip_if successful_requests.blank?,
                'No successful hook responses were received'

        requests.each_with_index do |request, index|
          cards = instructions_cards(request)

          instructions_count += cards.length

          perform_response_logical_model_validation(
            cards,
            nil,
            request.request_body,
            index,
            '2.2.1'
          )
        end

        skip_if instructions_count.zero?,
                "#{tested_hook_name} hook responses do not contain any Instructions cards."

        no_error_validation('Not all Instructions cards were valid. See messages for more information.')
      end
    end
  end
end
