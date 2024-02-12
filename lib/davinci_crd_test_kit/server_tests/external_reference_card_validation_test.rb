require_relative '../test_helper'

module DaVinciCRDTestKit
  class ExternalReferenceCardValidationTest < Inferno::Test
    include DaVinciCRDTestKit::TestHelper

    title 'Valid External Reference cards received'
    id :crd_external_reference_card_validation
    description %(
      This test verifies the presence of valid External Reference cards within the list of valid cards
      returned by the CRD service.
      As per the [Da Vinci CRD Implementation Guide](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#external-reference),
      External Reference cards must contain links with the type set to `absolute`.
      This test checks for the presence of any External Reference cards by verifying:
      - The presence of a `links` array within each card.
      - That every link in the `links` array of a card is of type `absolute`.
    )

    input :valid_cards_with_links
    optional

    def hook_name
      config.options[:hook_name]
    end

    run do
      parsed_cards = parse_json(valid_cards_with_links)
      external_reference_cards = parsed_cards.select do |card|
        links = card['links']
        links.present? && links.all? { |link| link['type'] == 'absolute' }
      end

      assert external_reference_cards.present?, "#{hook_name} hook response did not contain an External Reference card."
    end
  end
end
