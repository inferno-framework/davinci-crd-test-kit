require_relative '../test_helper'

module DaVinciCRDTestKit
  class ExternalReferenceCardAcrossHooksValidationTest < Inferno::Test
    include DaVinciCRDTestKit::TestHelper

    title 'Valid External Reference cards received across all hooks'
    id :crd_external_reference_card_across_hooks_validation
    description %(
      This test verifies the presence of valid External Reference returned by CRD services across all hooks invoked.
      As per the [Da Vinci CRD Implementation Guide](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#external-reference),
      External Reference cards must contain links with the type set to `absolute`.
      This test checks for the presence of any External Reference cards by verifying:
      - The presence of a `links` array within each card.
      - That every link in the `links` array of a card is of type `absolute`.

      The test will be skipped if no valid External Reference cards are returned across all hooks.
    )

    run do
      verify_at_least_one_test_passes(
        self.class.parent.parent.groups,
        'crd_external_reference_card_validation',
        'None of the hooks invoked returned an External Reference card.'
      )
    end
  end
end
