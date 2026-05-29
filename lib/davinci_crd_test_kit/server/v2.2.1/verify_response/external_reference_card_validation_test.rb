require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/cards_validation'

module DaVinciCRDTestKit
  module V221
    class ExternalReferenceCardValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::CardsValidation

      title 'External Reference cards are valid'
      id :crd_v221_external_reference_card_validation
      description %(
        This test verifies the presence of valid External Reference cards within the list of valid cards
        returned by the CRD service.
        As per the [Da Vinci CRD Implementation Guide](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#external-reference),
        External Reference cards must contain links with the type set to `absolute`.
        This test checks for the presence of any External Reference cards by verifying:
        - The presence of a `links` array within each card.
        - That every link in the `links` array of a card is of type `absolute`.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-22'

      input :valid_cards_with_links
      optional

      run do
        parsed_cards = parse_json(valid_cards_with_links)
        external_reference_cards = parsed_cards.select { |card| external_reference_response_type?(card) }

        skip_if external_reference_cards.blank?,
                "#{tested_hook_name} hook response does not contain any External Reference cards."

        external_reference_cards.each do |card|
          external_reference_card_check(card)
        end

        assert messages.blank?,
               'Not all External Reference cards were valid. See messages for more information.'
      end
    end
  end
end
