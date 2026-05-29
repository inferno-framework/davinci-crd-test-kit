require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/cards_validation'

module DaVinciCRDTestKit
  module V221
    class LaunchSmartAppCardValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::CardsValidation

      title 'Launch SMART Application cards are valid'
      id :crd_v221_launch_smart_app_card_validation
      description %(
        This test verifies the presence of valid Launch SMART Application cards within the list of valid cards
        returned by the CRD service.
        As per the [Da Vinci CRD Implementation Guide](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#launch-smart-application),
        Launch SMART Application cards must contain links with the type set to `smart`.
        This test checks for the presence of any Launch SMART Application cards by verifying:
        - The existence of a `links` array within each card.
        - That every link in the `links` array of a card is of type `smart`.

        The test will be skipped if no Launch SMART Application cards are found within the returned valid cards.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-72'

      optional
      input :valid_cards_with_links

      run do
        parsed_cards = parse_json(valid_cards_with_links)
        launch_smart_app_cards = parsed_cards.select { |card| launch_smart_app_response_type?(card) }

        skip_if launch_smart_app_cards.blank?,
                "#{tested_hook_name} hook response does not contain any Launch SMART App cards."

        launch_smart_app_cards.each do |card|
          smart_app_card_check(card)
        end

        assert messages.blank?,
               'Not all Launch SMART App cards were valid. See messages for more information.'
      end
    end
  end
end
