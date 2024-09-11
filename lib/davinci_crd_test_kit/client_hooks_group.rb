require_relative 'client_tests/client_appointment_book_group'
require_relative 'client_tests/client_display_cards_attest'
require_relative 'client_tests/client_encounter_discharge_group'
require_relative 'client_tests/client_encounter_start_group'
require_relative 'client_tests/client_order_dispatch_group'
require_relative 'client_tests/client_order_select_group'
require_relative 'client_tests/client_order_sign_group'
require_relative 'client_tests/decode_auth_token_test'
require_relative 'client_tests/encounter_discharge_receive_request_test'
require_relative 'client_tests/encounter_start_receive_request_test'
require_relative 'client_tests/hook_request_optional_fields_test'
require_relative 'client_tests/hook_request_required_fields_test'
require_relative 'client_tests/hook_request_valid_context_test'
require_relative 'client_tests/hook_request_valid_prefetch_test'
require_relative 'client_tests/order_dispatch_receive_request_test'
require_relative 'client_tests/order_select_receive_request_test'
require_relative 'client_tests/order_sign_receive_request_test'
require_relative 'client_tests/retrieve_jwks_test'
require_relative 'client_tests/submitted_response_validation'
require_relative 'client_tests/token_header_test'
require_relative 'client_tests/token_payload_test'

require_relative 'jwt_helper'
require_relative 'urls'

module DaVinciCRDTestKit
  class ClientHooksGroup < Inferno::TestGroup
    title 'Hooks'
    description <<~DESCRIPTION
      This Group contains tests which verify that valid hook requests can be made for each of the following
      [six hooks contained in the
        implementation guide](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html):
          * [appointment-book](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#appointment-book)
          * [encounter-start](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#encounter-start)
          * [encounter-discharge](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#encounter-discharge)
          * [order-select](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-select)
          * [order-dispatch](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-dispatch)
          * [order-sign](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-sign)

        Each hook group contains a test which waits for incoming hook requests from the CRD client, and tests which
        verify the incoming hook requests conform to the specific hook requirements specified the
        CRD IG and the [CDS hooks spec](https://cds-hooks.hl7.org/2.0/).

        Each hook group tests the following:
        * If the CRD Client can invoke the specific hook service request
        * If the incoming hook request is properly authorized with a JWT Bearer token according to the [CDS Hooks authorization requirements](https://cds-hooks.hl7.org/2.0/#trusting-cds-clients)
        * If the incoming hook request contains the required fields listed in the [CDS Hooks HTTP request requirements](https://cds-hooks.hl7.org/2.0/#http-request_1)
        * OPTIONAL: If the incoming hook request contains the optional fields listed in the [CDS Hooks HTTP request requirements](https://cds-hooks.hl7.org/2.0/#http-request_1)
        * If the hook request's `context` field is valid according to the specific `context` requirements defined for
        each hook type
        * OPTIONAL: If the incoming hook contains the optional `prefetch` field with valid resources
        * If the client can properly display the cards returned as a result of the hook request

        Note: In order to successfully return a `Coverage Information` system action, a Coverage resource must either be
        provided in the service request's `prefetch` field, or must be fetchable from the client's FHIR server for
        the patient provided in the service request.
    DESCRIPTION
    id :crd_client_hooks

    input :iss,
          title: 'JWT Issuer',
          description: 'The `iss` claim of the JWT in the Authorization header ' \
                       'will be used to associate incoming requests with this test session'

    group from: :crd_client_appointment_book,
          optional: true

    group from: :crd_client_encounter_start,
          optional: true

    group from: :crd_client_encounter_discharge,
          optional: true

    group from: :crd_client_order_select,
          optional: true

    group from: :crd_client_order_dispatch,
          optional: true

    group from: :crd_client_order_sign,
          optional: true
  end
end
