require_relative 'encounter_discharge_receive_request_test'
require_relative 'client_display_cards_attest'
require_relative 'decode_auth_token_test'
require_relative 'hook_request_optional_fields_test'
require_relative 'hook_request_required_fields_test'
require_relative 'hook_request_valid_context_test'
require_relative 'hook_request_valid_prefetch_test'
require_relative 'hook_request_fetched_data_test'
require_relative 'retrieve_jwks_test'
require_relative 'submitted_response_validation'
require_relative 'token_header_test'
require_relative 'token_payload_test'

module DaVinciCRDTestKit
  class ClientEncounterDischargeGroup < Inferno::TestGroup
    title 'encounter-discharge'
    id :crd_client_encounter_discharge
    description <<~DESCRIPTION
      The encounter-discharge hook is invoked when the user is performing the discharge process for an encounter where
      the notion of 'discharge' is relevant - typically an inpatient encounter. These tests are based on the
      following criteria:
        * [CRD IG requirements for this hook](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#encounter-discharge),
        which includes the profiles that are expected to be used for the resources resolved to by `context`
        FHIR ID fields
        * Specific [encounter-discharge `context` requirements](https://cds-hooks.hl7.org/hooks/encounter-discharge/2023SepSTU1Ballot/encounter-discharge/)
        defined in the CDS Hooks specification

      This version of the CRD implementation guide refers to version 1.0 of the hook.
    DESCRIPTION

    run_as_group

    input_order :cds_jwt_iss, :cds_jwk_set

    config(
      inputs: {
        auth_token_headers_json: { name: :encounter_discharge_auth_token_headers_json },
        auth_tokens: { name: :encounter_discharge_auth_tokens },
        auth_tokens_jwk_json: { name: :encounter_discharge_auth_tokens_jwk_json },
        client_access_token: { name: :encounter_discharge_client_access_token },
        client_fhir_server: { name: :encounter_discharge_client_fhir_server },
        crd_jwks_keys_json: { name: :encounter_discharge_crd_jwks_keys_json },
        custom_response: { name: :encounter_discharge_custom_response },
        selected_response_types: { name: :encounter_discharge_selected_response_types }
      },
      outputs: {
        auth_token_headers_json: { name: :encounter_discharge_auth_token_headers_json },
        auth_token_payloads_json: { name: :encounter_discharge_auth_token_payloads_json },
        auth_tokens: { name: :encounter_discharge_auth_tokens },
        auth_tokens_jwk_json: { name: :encounter_discharge_auth_tokens_jwk_json },
        client_access_token: { name: :encounter_discharge_client_access_token },
        client_fhir_server: { name: :encounter_discharge_client_fhir_server },
        crd_jwks_json: { name: :encounter_discharge_crd_jwks_json },
        crd_jwks_keys_json: { name: :encounter_discharge_crd_jwks_keys_json }
      },
      options: {
        hook_name: 'encounter-discharge',
        hook_path: ENCOUNTER_DISCHARGE_PATH
      }
    )

    test from: :crd_submitted_response_validation
    test from: :crd_encounter_discharge_request
    test from: :crd_decode_auth_token
    test from: :crd_retrieve_jwks
    test from: :crd_token_header
    test from: :crd_token_payload
    test from: :crd_hook_request_required_fields
    test from: :crd_hook_request_optional_fields
    test from: :crd_hook_request_valid_context
    test from: :crd_hook_request_valid_prefetch
    test from: :crd_hook_request_fetched_data
    test from: :crd_card_display_attest_test
  end
end
