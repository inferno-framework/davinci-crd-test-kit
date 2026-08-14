require_relative '../../../cross_suite/cards_identification'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V201
    class ClientCardMustSupportInstructionsTest < Inferno::Test
      include CardsIdentification
      include TaggedRequestLoadHelper

      title 'Instructions Card Support'
      id :crd_v201_client_card_must_support_instructions
      description <<~DESCRIPTION
        Checks that the client demonstrated support for the [Instructions](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#external-reference)
        card type. At least one hook invocation performed during this test session must have returned an Instructions card.

        If this test fails, adjust the [cards returned by Inferno's simulated CRD server](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses)
        and/or the hook requests made by the client during the Hooks tests such that an Instructions card is returned and support for it is demonstrated.
      DESCRIPTION

      run do
        loaded_requests = load_requests_for_cross_hook_analysis
        sorted_cards = sorted_cards_from_requests(loaded_requests)

        assert sorted_cards['cards'][INSTRUCTIONS_RESPONSE_TYPE].present?,
               'Instructions card support not demonstrated.'
      end
    end
  end
end
