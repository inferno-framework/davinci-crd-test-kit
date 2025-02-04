require_relative '../test_helper'
require_relative '../server_hook_helper'

module DaVinciCRDTestKit
  class LaunchSmartAppCardValidationTest < Inferno::Test
    include DaVinciCRDTestKit::TestHelper
    include DaVinciCRDTestKit::ServerHookHelper

    title 'Valid Launch SMART Application cards received'
    id :crd_launch_smart_app_card_validation
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

    optional
    input :valid_cards_with_links

    run do
      parsed_cards = parse_json(valid_cards_with_links)
      external_reference_cards = parsed_cards.select do |card|
        links = card['links']
        links.present? && links.all? { |link| link['type'] == 'smart' }
      end

      skip_if external_reference_cards.blank?,
              "#{tested_hook_name} hook response does not contain any Launch SMART App cards."
    end
  end
end
