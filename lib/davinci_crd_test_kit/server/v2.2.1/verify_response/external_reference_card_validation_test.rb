require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/response_logical_model_validation'

module DaVinciCRDTestKit
  module V221
    class ExternalReferenceCardValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::ResponseLogicalModelValidation

      title 'External Reference cards are valid'
      id :crd_v221_external_reference_card_validation
      description %(
        This test verifies the presence of valid External Reference cards within
        the CRD service responses.

        As per the [Da Vinci CRD Implementation
        Guide](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#external-reference-response-type),
        External Reference cards must contain links with the type set to
        `absolute`. This test checks for the presence of any External Reference
        cards by verifying:
        - The presence of a `links` array within each card.
        - That every link in the `links` array of a card is of type `absolute`.

        The test will be skipped if no External Reference cards are found within
        the returned valid cards.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-22'

      input :invoked_hook

      optional

      def body_has_no_cards?(body)
        !body.is_a?(Hash) ||
          body['cards'].blank? ||
          !body['cards'].is_a?(Array) ||
          !body['cards'].all?(Hash)
      end

      def external_reference_cards(request)
        return [] if request.status != 200

        response_body = JSON.parse(request.response_body)

        return [] if body_has_no_cards?(response_body)

        response_body['cards'].select { |card| external_reference_response_type? card }
      rescue JSON::ParserError
        []
      end

      run do
        load_tagged_requests(tested_hook_name)

        external_reference_count = 0

        successful_requests = requests.select { |request| request.status == 200 }

        skip_if successful_requests.blank?,
                'No successful hook responses were received'

        requests.each_with_index do |request, index|
          cards = external_reference_cards(request)

          external_reference_count += cards.length

          perform_response_logical_model_validation(
            cards,
            nil,
            request.request_body,
            index,
            '2.2.1'
          )
        end

        skip_if external_reference_count.zero?,
                "#{tested_hook_name} hook responses do not contain any External Reference cards."

        no_error_validation('Not all External Reference cards were valid. See messages for more information.')
      end
    end
  end
end
