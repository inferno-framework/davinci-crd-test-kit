require_relative 'invocation/cross_hooks_receive_request_test'
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
require_relative 'verify_response/hook_response_support_coverage_information_test'
require_relative 'client_urls'

module DaVinciCRDTestKit
  module V221
    class ClientCrossHookInteractionGroup < Inferno::TestGroup
      title 'Additional Hook Invocations for Cross Hook Support Demonstration'
      id :crd_v221_client_cross_hook_interaction
      description <<~DESCRIPTION
        Optionally send more hook requests demonstrating additional cross-hook
        features.

        Inferno's simulated hook endpoints can be discovered at:
        - Complete Prefetch: `#{ClientURLs.base_url}#{DISCOVERY_PATH}`
        - Subset Prefetch: `#{ClientURLs.base_url}#{PREFETCH_DISCOVERY_PATH}`
      DESCRIPTION
      run_as_group

      input_order :cross_hooks_response_approach,
                  :cross_hooks_selected_response_types,
                  :cross_hooks_custom_response_template

      config(
        inputs: {
          auth_token_headers_json: { name: :cross_hooks_auth_token_headers_json },
          auth_tokens: { name: :cross_hooks_auth_tokens },
          auth_tokens_jwk_json: { name: :cross_hooks_auth_tokens_jwk_json },
          client_access_token: { name: :cross_hooks_client_access_token },
          client_fhir_server: { name: :cross_hooks_client_fhir_server },
          crd_jwks_keys_json: { name: :cross_hooks_crd_jwks_keys_json },
          custom_response_template: { name: :cross_hooks_custom_response_template },
          selected_response_types: { name: :cross_hooks_selected_response_types }
        },
        outputs: {
          auth_token_headers_json: { name: :cross_hooks_auth_token_headers_json },
          auth_token_payloads_json: { name: :cross_hooks_auth_token_payloads_json },
          auth_tokens: { name: :cross_hooks_auth_tokens },
          auth_tokens_jwk_json: { name: :cross_hooks_auth_tokens_jwk_json },
          client_access_token: { name: :cross_hooks_client_access_token },
          client_fhir_server: { name: :cross_hooks_client_fhir_server },
          crd_jwks_keys_json: { name: :cross_hooks_crd_jwks_keys_json }
        },
        options: {
          hook_name: ANY_HOOK_TAG,
          crd_interaction_group: 'additional-cross-hooks',
          include_in_cross_hook_analysis: true
        }
      )

      group do
        title 'Interaction'
        test from: :crd_v221_cross_hooks_request
      end

      group do
        title 'Authorization'
        test from: :crd_v221_decode_auth_token
        test from: :crd_v221_retrieve_jwks
        test from: :crd_v221_token_header
        test from: :crd_v221_token_payload
      end

      group do
        title 'Requests'
        test from: :crd_v221_hook_request_conformance
        test from: :crd_v221_hook_request_requested_version
        test from: :crd_v221_hook_request_prefetch_profiles
        test from: :crd_v221_hook_request_prefetch_complete
        test from: :crd_v221_hook_request_coverage_verification
        test from: :crd_v221_hook_data_fetch_verification
        test from: :crd_v221_hook_request_granted_scopes
        test from: :crd_v221_hook_request_secured_transport
      end

      group do
        title 'Response Handling'

        test from: :crd_v221_inferno_response_validation
        test from: :crd_v221_card_display_attest_test
      end
    end
  end
end
