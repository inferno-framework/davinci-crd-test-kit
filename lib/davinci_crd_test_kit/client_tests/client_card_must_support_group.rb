require_relative 'client_card_must_support_coverage_information'
require_relative 'client_card_must_support_external_reference'
require_relative 'client_card_must_support_instructions'

module DaVinciCRDTestKit
  class ClientCardMustSupportGroup < Inferno::TestGroup
    title 'Card Must Support'
    id :crd_client_card_must_support
    description <<~DESCRIPTION
      CRD clients are required to support the following card types
      - [External Reference](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#external-reference)
      - [Instructions](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#instructions)
      - [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information)

      This group checks that instances of each of these card types were observed across all hook calls
      made by the client as a part of this test session. In the case of the Coverage Information card type,
      all must support elements defined in the [coverage-information extension](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information.html)
      must be demonstrated.

      These tests must be run after the tests in the Hooks group are run.
    DESCRIPTION

    run_as_group

    test from: :crd_client_card_must_support_coverage_information
    test from: :crd_client_card_must_support_external_reference
    test from: :crd_client_card_must_support_instructions
  end
end
