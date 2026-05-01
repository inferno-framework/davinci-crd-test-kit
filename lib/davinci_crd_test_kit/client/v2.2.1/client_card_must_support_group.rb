require_relative 'must_support/client_card_must_support_coverage_information'

module DaVinciCRDTestKit
  module V221
    class ClientCardMustSupportGroup < Inferno::TestGroup
      title 'Response Must Support'
      id :crd_v221_client_card_must_support
      description <<~DESCRIPTION
        CRD clients are required to support the [Coverage Information](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type)
        response type.

        This group checks that instances of this response were observed across all hook calls
        made by the client as a part of this test session. Additionally,
        all must support elements defined in the [coverage-information extension](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-ext-coverage-information.html)
        must be demonstrated.

        These tests must be run after the tests in the Hooks group are run.
      DESCRIPTION

      run_as_group

      test from: :crd_v221_client_card_must_support_coverage_information
    end
  end
end
