require_relative 'appointment_book_receive_request_test'
require_relative 'client_display_cards_attest'
require_relative 'decode_auth_token_test'
require_relative 'hook_request_optional_fields_test'
require_relative 'hook_request_required_fields_test'
require_relative 'hook_request_valid_context_test'
require_relative 'hook_request_valid_prefetch_test'
require_relative 'retrieve_jwks_test'
require_relative 'submitted_response_validation'
require_relative 'token_header_test'
require_relative 'token_payload_test'

module DaVinciCRDTestKit
  class ClientAppointmentBookGroup < Inferno::TestGroup
    title 'appointment-book'
    id :crd_client_appointment_book
    description <<~DESCRIPTION
      The appointment-book hook is invoked when the user is scheduling one or more future encounters/visits for the
      patient. These tests are based on the following criteria:
        * [CRD IG requirements for this hook](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#appointment-book),
        which include the profiles that are expected to be used for the resources resolved to by `context` FHIR ID
        fields
        * Specific [appointment-book `context` requirements](https://cds-hooks.hl7.org/hooks/appointment-book/2023SepSTU1Ballot/appointment-book/)
        defined in the CDS Hooks specification

      This version of the CRD implementation guide refers to version 1.0 of the hook.
    DESCRIPTION

    run_as_group

    config(
      inputs: {
        auth_token_headers_json: { name: :appointment_book_auth_token_headers_json },
        auth_tokens: { name: :appointment_book_auth_tokens },
        auth_tokens_jwk_json: { name: :appointment_book_auth_tokens_jwk_json },
        client_access_token: { name: :appointment_book_client_access_token },
        client_fhir_server: { name: :appointment_book_client_fhir_server },
        crd_jwks_keys_json: { name: :appointment_book_crd_jwks_keys_json },
        custom_response: { name: :appointment_book_custom_response },
        selected_response_types: { name: :appointment_book_selected_response_types }
      },
      outputs: {
        auth_token_headers_json: { name: :appointment_book_auth_token_headers_json },
        auth_token_payloads_json: { name: :appointment_book_auth_token_payloads_json },
        auth_tokens: { name: :appointment_book_auth_tokens },
        auth_tokens_jwk_json: { name: :appointment_book_auth_tokens_jwk_json },
        client_access_token: { name: :appointment_book_client_access_token },
        client_fhir_server: { name: :appointment_book_client_fhir_server },
        crd_jwks_json: { name: :appointment_book_crd_jwks_json },
        crd_jwks_keys_json: { name: :appointment_book_crd_jwks_keys_json }
      },
      options: {
        hook_name: 'appointment-book',
        hook_path: APPOINTMENT_BOOK_PATH
      }
    )

    test from: :crd_submitted_response_validation
    test from: :crd_appointment_book_request
    test from: :crd_decode_auth_token
    test from: :crd_retrieve_jwks
    test from: :crd_token_header
    test from: :crd_token_payload
    test from: :crd_hook_request_required_fields
    test from: :crd_hook_request_optional_fields
    test from: :crd_hook_request_valid_context
    test from: :crd_hook_request_valid_prefetch
    test from: :crd_card_display_attest_test
  end
end
