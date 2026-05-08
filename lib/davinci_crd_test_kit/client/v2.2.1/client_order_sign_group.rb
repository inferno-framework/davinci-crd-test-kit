require_relative 'invocation/order_sign_receive_request_test'
require_relative 'auth/decode_auth_token_test'
require_relative 'auth/retrieve_jwks_test'
require_relative 'auth/token_header_test'
require_relative 'auth/token_payload_test'
require_relative 'verify_request/hook_request_conformance_test'
require_relative 'verify_request/hook_request_requested_version_test'
require_relative 'verify_request/hook_request_prefetch_profiles_test'
require_relative 'verify_request/hook_request_prefetch_complete_test'
require_relative 'verify_request/hook_request_granted_scopes_test'
require_relative 'verify_request/hook_request_secured_transport_test'
require_relative 'verify_request/hook_request_coverage_verification_test'
require_relative 'verify_request/hook_request_data_fetch_verification_test'
require_relative 'verify_response/inferno_response_validation'
require_relative 'verify_response/client_display_cards_attest'

module DaVinciCRDTestKit
  module V221
    class ClientOrderSignGroup < Inferno::TestGroup
      title 'order-sign'
      id :crd_v221_client_order_sign
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

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@hook-2-A', 'hl7.fhir.us.davinci-crd_2.2.1@hook-2-B'

      input_order :cds_jwt_iss, :cds_jwk_set

      config(
        inputs: {
          auth_token_headers_json: { name: :order_sign_auth_token_headers_json },
          auth_tokens: { name: :order_sign_auth_tokens },
          auth_tokens_jwk_json: { name: :order_sign_auth_tokens_jwk_json },
          client_access_token: { name: :order_sign_client_access_token },
          client_fhir_server: { name: :order_sign_client_fhir_server },
          crd_jwks_keys_json: { name: :order_sign_crd_jwks_keys_json },
          custom_response_template: { name: :order_sign_custom_response_template },
          selected_response_types: { name: :order_sign_selected_response_types }
        },
        outputs: {
          auth_token_headers_json: { name: :order_sign_auth_token_headers_json },
          auth_token_payloads_json: { name: :order_sign_auth_token_payloads_json },
          auth_tokens: { name: :order_sign_auth_tokens },
          auth_tokens_jwk_json: { name: :order_sign_auth_tokens_jwk_json },
          client_access_token: { name: :order_sign_client_access_token },
          client_fhir_server: { name: :order_sign_client_fhir_server },
          crd_jwks_keys_json: { name: :order_sign_crd_jwks_keys_json }
        },
        options: {
          hook_name: 'order-sign'
        }
      )

      group do
        title 'Make Hook Requests'
        test from: :crd_v221_order_sign_request
      end

      group do
        title 'Verify Authorization'
        test from: :crd_v221_decode_auth_token
        test from: :crd_v221_retrieve_jwks
        test from: :crd_v221_token_header
        test from: :crd_v221_token_payload
      end

      group do
        title 'Verify Requests'
        test from: :crd_v221_hook_request_conformance do
          verifies_requirements(*HookRequestConformanceTest.verifies_requirements,
                                'hl7.fhir.us.davinci-crd_2.2.1@hook-37')
        end
        test from: :crd_v221_hook_request_requested_version
        test from: :crd_v221_hook_request_prefetch_profiles
        test from: :crd_v221_hook_request_prefetch_complete
        test from: :crd_v221_hook_request_coverage_verification
        test from: :crd_v221_hook_data_fetch_verification
        test from: :crd_v221_hook_request_granted_scopes
        test from: :crd_v221_hook_request_secured_transport
      end

      group do
        title 'Verify Response Handling'

        test from: :crd_v221_inferno_response_validation
        test from: :crd_v221_card_display_attest_test
      end
    end
  end
end
