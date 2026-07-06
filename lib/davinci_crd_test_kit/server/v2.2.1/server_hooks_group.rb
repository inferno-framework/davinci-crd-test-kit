require_relative 'server_appointment_book_group'
require_relative 'server_encounter_start_group'
require_relative 'server_encounter_discharge_group'
require_relative 'server_order_select_group'
require_relative 'server_order_dispatch_group'
require_relative 'server_order_sign_group'
require_relative 'server_required_card_response_validation_group'

module DaVinciCRDTestKit
  module V221
    class ServerHooksGroup < Inferno::TestGroup
      title 'Hooks'
      id :crd_v221_server_hooks
      description %(
        # Background

        The #{title} Group verifies that a CRD Server supports at least one of
        the hooks supported by the [CRD
        IG](https://hl7.org/fhir/us/davinci-crd/2.2.1/hooks.html#supported-hooks).
        The supported hooks include:
        - [appointment-book](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#appointment-book)
        - [encounter-start](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#encounter-start)
        - [encounter-discharge](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#encounter-discharge)
        - [order-select](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#order-select)
        - [order-dispatch](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#order-dispatch)
        - [order-sign](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#order-sign)

        The [CRD 2.2.1 IG section on Supported Hooks](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#supported-hooks)
        states that "CRD Servers conforming to this implementation guide
        SHALL provide a service for all hooks and order resource types required of
        CRD clients by this implementation guide unless the server has determined that
        the hook will not be reasonably useful in determining coverage or documentation
        expectations for the types of coverage provided."

        # Test Methodology

        In these tests, Inferno acts as a CRD Client that initiates CDS Hooks
        calls. This test sequence is broken up into groups, each group
        corresponding to a supported hook and defining a set of tests verifying
        the ability of the server to respond to the given hook invocation. An
        additional group checks that the Coverage Information response type is
        supported for at least one hook.

        Each hook group test verifies that:
        - The hook can be invoked.
        - The user-provided request payload is valid as specified
          in the [CDS Hooks section on HTTP request requirements](https://cds-hooks.hl7.org/2026Jan/en/index.html#http-request-1).
        - Each card and system action returned by the server is valid as described in the
          [CDS Hooks section on CDS Service Response](https://cds-hooks.hl7.org/2026Jan/en/#cds-service-response).
        - Each [CRD response type](https://hl7.org/fhir/us/davinci-crd/2.2.1/cards.html#potential-crd-response-types)
          returned is valid - optional for some response types. See the individual test groups for more details.
      )

      group from: :crd_v221_server_appointment_book,
            optional: true
      group from: :crd_v221_server_encounter_start,
            optional: true
      group from: :crd_v221_server_encounter_discharge,
            optional: true
      group from: :crd_v221_server_order_select,
            optional: true
      group from: :crd_v221_server_order_dispatch,
            optional: true
      group from: :crd_v221_server_order_sign,
            optional: true
      group from: :crd_v221_server_required_card_response_validation
    end
  end
end
