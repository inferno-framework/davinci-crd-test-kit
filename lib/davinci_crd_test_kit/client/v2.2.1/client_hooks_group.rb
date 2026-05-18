require_relative 'client_appointment_book_group'
require_relative 'client_encounter_discharge_group'
require_relative 'client_encounter_start_group'
require_relative 'client_order_dispatch_group'
require_relative 'client_order_select_group'
require_relative 'client_order_sign_group'

module DaVinciCRDTestKit
  module V221
    class ClientHooksGroup < Inferno::TestGroup
      title 'Hooks'
      description <<~DESCRIPTION
        This group contains sub-groups which each verify the ability of the client to make and react to responses from
        one of the [six hooks described in the CRD IG](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html):
        * [appointment-book](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#appointment-book)
        * [encounter-start](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#encounter-start)
        * [encounter-discharge](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#encounter-discharge)
        * [order-select](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#order-select)
        * [order-dispatch](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#order-dispatch)
        * [order-sign](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#order-sign)

        Each hook-specific group follows the same pattern:
        1. Allow the client to make hook invocations for the tested hook, waiting until the tester indicates
           that all desired requests have been made, then
        2. Check the requests and their associated responses for conformance to CRD and CDS Hooks requirements.
           Additionally, ask the tester to confirm that the responses were displayed appropriately by the client.

        The CRD IG does not require support for any specific hook, so all the hook-specific sub-groups are
        optional. A conformant CRD client will have implemented at least one hook and will run and pass
        the hook-specific groups corresponding to each hook that it implements.
      DESCRIPTION
      id :crd_v221_client_hooks

      input :cds_jwt_iss,
            title: 'CRD JWT Issuer',
            description: %(
              Value of the `iss` claim that must be present in the JWT used to authorize the client's hook
              request sent as the Bearer token in the `Authorization` header.
              Run or re-run the "Registration" group to set or change this value.
            ),
            locked: true

      input_order :cds_jwt_iss, :cds_jwk_set

      group from: :crd_v221_client_appointment_book,
            optional: true

      group from: :crd_v221_client_encounter_start,
            optional: true

      group from: :crd_v221_client_encounter_discharge,
            optional: true

      group from: :crd_v221_client_order_select,
            optional: true

      group from: :crd_v221_client_order_dispatch,
            optional: true

      group from: :crd_v221_client_order_sign,
            optional: true
    end
  end
end
