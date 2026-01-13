require_relative 'encounter_start_receive_request_test'
require_relative 'client_display_cards_attest'
require_relative 'decode_auth_token_test'
require_relative 'hook_request_optional_fields_test'
require_relative 'hook_request_required_fields_test'
require_relative 'hook_request_valid_context_test'
require_relative 'hook_request_valid_prefetch_test'
require_relative 'retrieve_jwks_test'
require_relative 'inferno_response_validation'
require_relative 'token_header_test'
require_relative 'token_payload_test'

module DaVinciCRDTestKit
  class ClientEncounterStartGroup < Inferno::TestGroup
    title 'encounter-start'
    id :crd_client_encounter_start
    description <<~DESCRIPTION
      The encounter-start hook is invoked when the user is initiating a new encounter. These tests are based on the
      following criteria:
        * [CRD IG requirements for this hook](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#encounter-start),
        which include the profiles that are expected to be used for the resources resolved to by `context` FHIR ID
        fields
        * Specific [encounter-start `context` requirements](https://cds-hooks.hl7.org/hooks/encounter-start/2023SepSTU1Ballot/encounter-start/)
        defined in the CDS Hooks specification

      This version of the CRD implementation guide refers to version 1.0 of the hook.
    DESCRIPTION
    verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@187'

    run_as_group

    input_order :cds_jwt_iss, :cds_jwk_set

    config(
      inputs: {
        auth_token_headers_json: { name: :encounter_start_auth_token_headers_json },
        auth_tokens: { name: :encounter_start_auth_tokens },
        auth_tokens_jwk_json: { name: :encounter_start_auth_tokens_jwk_json },
        client_access_token: { name: :encounter_start_client_access_token },
        client_fhir_server: { name: :encounter_start_client_fhir_server },
        crd_jwks_keys_json: { name: :encounter_start_crd_jwks_keys_json },
        custom_response_template: { name: :encounter_start_custom_response_template },
        selected_response_types: { name: :encounter_start_selected_response_types }
      },
      outputs: {
        auth_token_headers_json: { name: :encounter_start_auth_token_headers_json },
        auth_token_payloads_json: { name: :encounter_start_auth_token_payloads_json },
        auth_tokens: { name: :encounter_start_auth_tokens },
        auth_tokens_jwk_json: { name: :encounter_start_auth_tokens_jwk_json },
        client_access_token: { name: :encounter_start_client_access_token },
        client_fhir_server: { name: :encounter_start_client_fhir_server },
        crd_jwks_json: { name: :encounter_start_crd_jwks_json },
        crd_jwks_keys_json: { name: :encounter_start_crd_jwks_keys_json }
      },
      options: {
        hook_name: 'encounter-start',
        hook_path: ENCOUNTER_START_PATH
      }
    )

    test from: :crd_encounter_start_request
    test from: :crd_decode_auth_token
    test from: :crd_retrieve_jwks
    test from: :crd_token_header
    test from: :crd_token_payload
    test from: :crd_hook_request_required_fields
    test from: :crd_hook_request_optional_fields
    test from: :crd_hook_request_valid_context
    test from: :crd_hook_request_valid_prefetch
    test from: :crd_inferno_response_validation
    test from: :crd_card_display_attest_test
  end
end
