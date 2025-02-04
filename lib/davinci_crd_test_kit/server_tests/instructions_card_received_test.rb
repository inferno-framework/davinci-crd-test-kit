require_relative '../test_helper'
require_relative '../server_hook_helper'

module DaVinciCRDTestKit
  class InstructionsCardReceivedTest < Inferno::Test
    include DaVinciCRDTestKit::TestHelper
    include DaVinciCRDTestKit::ServerHookHelper

    title 'Valid Instructions cards received'
    id :crd_valid_instructions_card_received
    description %(
      This test validates that an [Instructions](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#instructions)
      card was received. It does so by:
      - Checking for the presence of a valid card that does not contain the `links` field and the `suggestions` field.
    )

    input :valid_cards
    optional

    run do
      parsed_cards = parse_json(valid_cards)
      instructions_card = parsed_cards.find { |card| card['links'].blank? && card['suggestions'].blank? }
      assert instructions_card, "#{tested_hook_name} hook response did not contain an Instructions card."
    end
  end
end
