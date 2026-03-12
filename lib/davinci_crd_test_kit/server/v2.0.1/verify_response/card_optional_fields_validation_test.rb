require_relative '../test_helper'
require_relative '../cards_validation'

module DaVinciCRDTestKit
  class CardOptionalFieldsValidationTest < Inferno::Test
    include DaVinciCRDTestKit::TestHelper
    include DaVinciCRDTestKit::CardsValidation

    title 'Cards contain valid optional fields'
    id :crd_card_optional_fields_validation
    description %(
      This test checks for the presence and validity of optional fields in a card,
      but only if the card's required fields are valid. As specified in the
      [CDS Hooks specification section on Card Attributes](https://cds-hooks.hl7.org/2.0/#card-attributes),
      the optional fields include `uuid`, `detail`, `suggestions`, `overrideReasons`, and `links`.

      Additionally, the test validates the presence of the conditional field `selectionBehavior`
      only if the `suggestions` field is present.
    )
    optional
    input :valid_cards
    output :valid_cards_with_links, :valid_cards_with_suggestions

    def cards_with_suggestions
      @cards_with_suggestions ||= []
    end

    def cards_with_links
      @cards_with_links ||= []
    end

    run do
      parsed_cards = parse_json(valid_cards)
      parsed_cards.each do |card|
        if valid_card_with_optionals?(card)
          cards_with_links << card if card['links']
          cards_with_suggestions << card if card['suggestions']
        end
      end

      output valid_cards_with_links: cards_with_links.to_json
      output valid_cards_with_suggestions: cards_with_suggestions.to_json

      no_error_validation('Some cards with valid required fields have invalid optional fields.')
    end
  end
end
