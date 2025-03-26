require_relative 'order_sign_receive_request_test'
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
  class ClientOrderSignGroup < Inferno::TestGroup
    title 'order-sign'
    id :crd_client_order_sign
    description <<~DESCRIPTION
      The order-sign hook fires when a clinician is ready to sign one or more orders for a patient, (including orders
      for medications, procedures, labs and other orders). These tests are based on the following criteria:
        * [CRD IG requirements for this hook](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-sign),
        which includes the profiles that are expected to be used for the resources resolved to by `context`
        FHIR ID fields
        * Specific [order-sign `context` requirements](https://cds-hooks.org/hooks/order-sign/)
        defined in the CDS Hooks specification

      This version of the CRD implementation guide refers to version 1.1 of the hook which, at the time of publication,
      was not available as a snapshot. Therefore the preceding link refers to the CDS hooks current build.
    DESCRIPTION

    run_as_group

    input_order :cds_jwt_iss, :cds_jwk_set

    config(
      inputs: {
        auth_token_headers_json: { name: :order_sign_auth_token_headers_json },
        auth_tokens: { name: :order_sign_auth_tokens },
        auth_tokens_jwk_json: { name: :order_sign_auth_tokens_jwk_json },
        client_access_token: { name: :order_sign_client_access_token },
        client_fhir_server: { name: :order_sign_client_fhir_server },
        crd_jwks_keys_json: { name: :order_sign_crd_jwks_keys_json },
        custom_response: { name: :order_sign_custom_response },
        selected_response_types: { name: :order_sign_selected_response_types }
      },
      outputs: {
        auth_token_headers_json: { name: :order_sign_auth_token_headers_json },
        auth_token_payloads_json: { name: :order_sign_auth_token_payloads_json },
        auth_tokens: { name: :order_sign_auth_tokens },
        auth_tokens_jwk_json: { name: :order_sign_auth_tokens_jwk_json },
        client_access_token: { name: :order_sign_client_access_token },
        client_fhir_server: { name: :order_sign_client_fhir_server },
        crd_jwks_json: { name: :order_sign_crd_jwks_json },
        crd_jwks_keys_json: { name: :order_sign_crd_jwks_keys_json }
      },
      options: {
        hook_name: 'order-sign',
        hook_path: ORDER_SIGN_PATH
      }
    )

    test from: :crd_submitted_response_validation
    test from: :crd_order_sign_request
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
