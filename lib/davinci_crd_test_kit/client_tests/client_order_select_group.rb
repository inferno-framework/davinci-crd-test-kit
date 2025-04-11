require_relative 'order_select_receive_request_test'
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
  class ClientOrderSelectGroup < Inferno::TestGroup
    title 'order-select'
    id :crd_client_order_select
    description <<~DESCRIPTION
      The order-select hook fires when a clinician selects one or more orders to place for a patient,
      (including orders for medications, procedures, labs and other orders). If supported by the CDS Client, this
      hook may also be invoked each time the clinician selects a detail regarding the order. These tests are based on
      the following criteria:
        * [CRD IG requirements for this hook](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-selecte),
        which includes the profiles that are expected to be used for the resources resolved to by `context`
        FHIR ID fields
        * Specific [order-select `context` requirements](https://cds-hooks.hl7.org/hooks/order-select/2023SepSTU1Ballot/order-select/)
        defined in the CDS Hooks specification

      This version of the CRD implementation guide refers to version 1.0 of the hook.
    DESCRIPTION

    run_as_group

    config(
      inputs: {
        auth_token_headers_json: { name: :order_select_auth_token_headers_json },
        auth_tokens: { name: :order_select_auth_tokens },
        auth_tokens_jwk_json: { name: :order_select_auth_tokens_jwk_json },
        client_access_token: { name: :order_select_client_access_token },
        client_fhir_server: { name: :order_select_client_fhir_server },
        crd_jwks_keys_json: { name: :order_select_crd_jwks_keys_json },
        custom_response: { name: :order_select_custom_response },
        selected_response_types: { name: :order_select_selected_response_types }
      },
      outputs: {
        auth_token_headers_json: { name: :order_select_auth_token_headers_json },
        auth_token_payloads_json: { name: :order_select_auth_token_payloads_json },
        auth_tokens: { name: :order_select_auth_tokens },
        auth_tokens_jwk_json: { name: :order_select_auth_tokens_jwk_json },
        client_access_token: { name: :order_select_client_access_token },
        client_fhir_server: { name: :order_select_client_fhir_server },
        crd_jwks_json: { name: :order_select_crd_jwks_json },
        crd_jwks_keys_json: { name: :order_select_crd_jwks_keys_json }
      },
      options: {
        hook_name: 'order-select',
        hook_path: ORDER_SELECT_PATH
      }
    )

    test from: :crd_submitted_response_validation
    test from: :crd_order_select_request
    test from: :crd_decode_auth_token
    test from: :crd_retrieve_jwks
    test from: :crd_token_header
    test from: :crd_token_payload
    test from: :crd_hook_request_required_fields
    test from: :crd_hook_request_optional_fields
    test from: :crd_hook_request_valid_context do
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@71', 'hl7.fhir.us.davinci-crd_2.0.1@284',
                            'hl7.fhir.us.davinci-crd_2.0.1@285', 'hl7.fhir.us.davinci-crd_2.0.1@286',
                            'hl7.fhir.us.davinci-crd_2.0.1@287', 'hl7.fhir.us.davinci-crd_2.0.1@288',
                            'hl7.fhir.us.davinci-crd_2.0.1@289', 'hl7.fhir.us.davinci-crd_2.0.1@290',
                            'hl7.fhir.us.davinci-crd_2.0.1@291', 'hl7.fhir.us.davinci-crd_2.0.1@292',
                            'hl7.fhir.us.davinci-crd_2.0.1@294', 'hl7.fhir.us.davinci-crd_2.0.1@295'
    end
    test from: :crd_hook_request_valid_prefetch
    test from: :crd_card_display_attest_test
  end
end
