require_relative 'server_appointment_book_group'
require_relative 'server_encounter_start_group'
require_relative 'server_encounter_discharge_group'
require_relative 'server_order_select_group'
require_relative 'server_order_dispatch_group'
require_relative 'server_order_sign_group'
require_relative 'server_required_card_response_validation_group'

module DaVinciCRDTestKit
  class ServerHooksGroup < Inferno::TestGroup
    title 'Hook Tests'
    id :crd_server_hooks
    description %(
      # Background

      The #{title} Group verifies that a [CRD Server](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-server.html)
      supports at least one of the hooks supported by the [CRD IG](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#supported-hooks).
      The supported hooks include:
      - [appointment-book](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#appointment-book)
      - [encounter-start](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#encounter-start)
      - [encounter-discharge](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#encounter-discharge)
      - [order-select](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-select)
      - [order-dispatch](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-dispatch)
      - [order-sign](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-sign)

      The [CRD STU2 IG section on Supported Hooks](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#supported-hooks)
      states that "CRD Servers conforming to this implementation guide
      SHALL provide a service for all hooks and order resource types required of
      CRD clients by this implementation guide unless the server has determined that
      the hook will not be reasonably useful in determining coverage or documentation
      expectations for the types of coverage provided."

      # Test Methodology

      In these tests, Inferno acts as a [CRD Client](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html)
      that initiates CDS Hooks calls. This test sequence is broken up into groups,
      each group corresponding to a supported hook and defining a set of tests verifying
      the ability of the server to respond to the given hook invocation. Additionally, an additional
      group checks the required [response types](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#potential-crd-response-types)
      across all hooks invoked.

      Each hook group test verifies that:
      - The hook can be invoked.
      - The user-provided request payload contains the required fields as specified
        in the [CDS Hooks section on HTTP request requirements](https://cds-hooks.hl7.org/2.0/#http-request_1).
      - The user-provided request payload contains the optional fields as specified
        in the [CDS Hooks section on HTTP request requirements](https://cds-hooks.hl7.org/2.0/#http-request_1) -
        optional.
      - Each card and system action returned by the server is valid as described in the
        [CDS Hooks section on CDS Service Response](https://cds-hooks.hl7.org/2.0/#cds-service-response).
      - Each [CRD response type](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#potential-crd-response-types)
        returned is valid - optional for some response types. See the individual test groups for more details.
    )
    verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@4', 'hl7.fhir.us.davinci-crd_2.0.1@152',
                          'hl7.fhir.us.davinci-crd_2.0.1@153'

    group from: :crd_server_appointment_book,
          optional: true
    group from: :crd_server_encounter_start,
          optional: true
    group from: :crd_server_encounter_discharge,
          optional: true
    group from: :crd_server_order_select,
          optional: true
    group from: :crd_server_order_dispatch,
          optional: true
    group from: :crd_server_order_sign,
          optional: true
    group from: :crd_server_required_card_response_validation
  end
end
