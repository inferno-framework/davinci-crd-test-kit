require_relative 'client_tests/appointment_book_receive_request_test'
require_relative 'client_tests/client_display_cards_attest'
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

    group do
      title 'appointment-book'
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

      optional
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

    group do
      title 'encounter-start'
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

      optional
      run_as_group

      config(
        inputs: {
          custom_response: { name: :encounter_start_custom_response }
        }
      )

      test from: :crd_submitted_response_validation,
           config: {
             options: {
               hook_name: 'encounter-start'
             }
           }

      test from: :crd_encounter_start_request

      test from: :crd_decode_auth_token,
           config: {
             options: {
               hook_name: 'encounter-discharge'
             },
             outputs: {
               auth_tokens: { name: :encounter_start_auth_tokens },
               auth_token_payloads_json: { name: :encounter_start_auth_token_payloads_json },
               auth_token_headers_json: { name: :encounter_start_auth_token_headers_json }
             }
           }
      test from: :crd_retrieve_jwks,
           config: {
             inputs: {
               auth_token_headers_json: { name: :encounter_start_auth_token_headers_json }
             },
             outputs: {
               crd_jwks_json: { name: :encounter_start_crd_jwks_json },
               crd_jwks_keys_json: { name: :encounter_start_crd_jwks_keys_json }
             }
           }
      test from: :crd_token_header,
           config: {
             inputs: {
               auth_token_headers_json: { name: :encounter_start_auth_token_headers_json },
               crd_jwks_keys_json: { name: :encounter_start_crd_jwks_keys_json }
             },
             outputs: {
               auth_tokens_jwk_json: { name: :encounter_start_auth_tokens_jwk_json }
             }
           }
      test from: :crd_token_payload,
           config: {
             options: { hook_path: ENCOUNTER_START_PATH },
             inputs: {
               auth_tokens: { name: :encounter_start_auth_tokens },
               auth_tokens_jwk_json: { name: :encounter_start_auth_tokens_jwk_json }
             }
           }

      test from: :crd_hook_request_required_fields,
           config: {
             options: {
               hook_name: 'encounter-start'
             }
           }
      test from: :crd_hook_request_optional_fields,
           config: {
             options: {
               hook_name: 'encounter-start'
             },
             outputs: {
               client_fhir_server: { name: :encounter_start_client_fhir_server },
               client_access_token: { name: :encounter_start_client_access_token }
             }
           }

      test from: :crd_hook_request_valid_context,
           config: {
             inputs: {
               client_fhir_server: { name: :encounter_start_client_fhir_server },
               client_access_token: { name: :encounter_start_client_access_token }
             },
             options: { hook_name: 'encounter-start' }
           }

      test from: :crd_hook_request_valid_prefetch,
           config: {
             options: { hook_name: 'encounter-discharge' }
           }

      test from: :crd_card_display_attest_test,
           config: {
             inputs: {
               selected_response_types: { name: :encounter_start_selected_response_types }
             }
           }
    end

    group do
      title 'encounter-discharge'
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

      optional
      run_as_group

      config(
        inputs: {
          custom_response: { name: :encounter_discharge_custom_response }
        }
      )

      test from: :crd_submitted_response_validation,
           config: {
             options: {
               hook_name: 'encounter-discharge'
             }
           }

      test from: :crd_encounter_discharge_request

      test from: :crd_decode_auth_token,
           config: {
             options: {
               hook_name: 'encounter-discharge'
             },
             outputs: {
               auth_tokens: { name: :encounter_discharge_auth_tokens },
               auth_token_payloads_json: { name: :encounter_discharge_auth_token_payloads_json },
               auth_token_headers_json: { name: :encounter_discharge_auth_token_headers_json }
             }
           }
      test from: :crd_retrieve_jwks,
           config: {
             inputs: {
               auth_token_headers_json: { name: :encounter_discharge_auth_token_headers_json }
             },
             outputs: {
               crd_jwks_json: { name: :encounter_discharge_crd_jwks_json },
               crd_jwks_keys_json: { name: :encounter_discharge_crd_jwks_keys_json }
             }
           }
      test from: :crd_token_header,
           config: {
             inputs: {
               auth_token_headers_json: { name: :encounter_discharge_auth_token_headers_json },
               crd_jwks_keys_json: { name: :encounter_discharge_crd_jwks_keys_json }
             },
             outputs: {
               auth_tokens_jwk_json: { name: :encounter_discharge_auth_tokens_jwk_json }
             }
           }
      test from: :crd_token_payload,
           config: {
             options: { hook_path: ENCOUNTER_DISCHARGE_PATH },
             inputs: {
               auth_tokens: { name: :encounter_discharge_auth_tokens },
               auth_tokens_jwk_json: { name: :encounter_discharge_auth_tokens_jwk_json }
             }
           }

      test from: :crd_hook_request_required_fields,
           config: {
             options: {
               hook_name: 'encounter-discharge'
             }
           }
      test from: :crd_hook_request_optional_fields,
           config: {
             options: {
               hook_name: 'encounter-discharge'
             },
             outputs: {
               client_fhir_server: { name: :encounter_discharge_client_fhir_server },
               client_access_token: { name: :encounter_discharge_client_access_token }
             }
           }

      test from: :crd_hook_request_valid_context,
           config: {
             inputs: {
               client_fhir_server: { name: :encounter_discharge_client_fhir_server },
               client_access_token: { name: :encounter_discharge_client_access_token }
             },
             options: { hook_name: 'encounter-discharge' }
           }

      test from: :crd_hook_request_valid_prefetch,
           config: {
             options: { hook_name: 'encounter-discharge' }
           }

      test from: :crd_card_display_attest_test,
           config: {
             inputs: {
               selected_response_types: { name: :encounter_discharge_selected_response_types }
             }
           }
    end

    group do
      title 'order-select'
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

      optional
      run_as_group

      config(
        inputs: {
          custom_response: { name: :order_select_custom_response }
        }
      )

      test from: :crd_submitted_response_validation,
           config: {
             options: {
               hook_name: 'order-select'
             }
           }

      test from: :crd_order_select_request

      test from: :crd_decode_auth_token,
           config: {
             options: {
               hook_name: 'order-select'
             },
             outputs: {
               auth_tokens: { name: :order_select_auth_tokens },
               auth_token_payloads_json: { name: :order_select_auth_token_payloads_json },
               auth_token_headers_json: { name: :order_select_auth_token_headers_json }
             }
           }
      test from: :crd_retrieve_jwks,
           config: {
             inputs: {
               auth_token_headers_json: { name: :order_select_auth_token_headers_json }
             },
             outputs: {
               crd_jwks_json: { name: :order_select_crd_jwks_json },
               crd_jwks_keys_json: { name: :order_select_crd_jwks_keys_json }
             }
           }
      test from: :crd_token_header,
           config: {
             inputs: {
               auth_token_headers_json: { name: :order_select_auth_token_headers_json },
               crd_jwks_keys_json: { name: :order_select_crd_jwks_keys_json }
             },
             outputs: {
               auth_tokens_jwk_json: { name: :order_select_auth_tokens_jwk_json }
             }
           }
      test from: :crd_token_payload,
           config: {
             options: { hook_path: ORDER_SELECT_PATH },
             inputs: {
               auth_tokens: { name: :order_select_auth_tokens },
               auth_tokens_jwk_json: { name: :order_select_auth_tokens_jwk_json }
             }
           }

      test from: :crd_hook_request_required_fields,
           config: {
             options: {
               hook_name: 'order-select'
             }
           }
      test from: :crd_hook_request_optional_fields,
           config: {
             options: {
               hook_name: 'order-select'
             },
             outputs: {
               client_fhir_server: { name: :order_select_client_fhir_server },
               client_access_token: { name: :order_select_client_access_token }
             }
           }

      test from: :crd_hook_request_valid_context,
           config: {
             inputs: {
               client_fhir_server: { name: :order_select_client_fhir_server },
               client_access_token: { name: :order_select_client_access_token }
             },
             options: { hook_name: 'order-select' }
           }

      test from: :crd_hook_request_valid_prefetch,
           config: {
             options: { hook_name: 'order-select' }
           }

      test from: :crd_card_display_attest_test,
           config: {
             inputs: {
               selected_response_types: { name: :order_select_selected_response_types }
             }
           }
    end

    group do
      title 'order-dispatch'
      description <<~DESCRIPTION
        The order-dispatch hook fires when a practitioner is selecting a candidate performer for a pre-existing order
        that was not tied to a specific performer. These tests are based on the following criteria:
          * [CRD IG requirements for this hook](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-dispatch),
          which includes the profiles that are expected to be used for the resources resolved to by `context`
          FHIR ID fields
          * Specific [order-dispatch `context` requirements](https://cds-hooks.hl7.org/hooks/order-dispatch/2023SepSTU1Ballot/order-dispatch/)
          defined in the CDS Hooks specification

        This version of the CRD implementation guide refers to version 1.0 of the hook.
      DESCRIPTION

      optional
      run_as_group

      config(
        inputs: {
          custom_response: { name: :order_dispatch_custom_response }
        }
      )

      test from: :crd_submitted_response_validation,
           config: {
             options: {
               hook_name: 'order-dispatch'
             }
           }

      test from: :crd_order_dispatch_request

      test from: :crd_decode_auth_token,
           config: {
             options: {
               hook_name: 'order-dispatch'
             },
             outputs: {
               auth_tokens: { name: :order_dispatch_auth_tokens },
               auth_token_payloads_json: { name: :order_dispatch_auth_token_payloads_json },
               auth_token_headers_json: { name: :order_dispatch_auth_token_headers_json }
             }
           }
      test from: :crd_retrieve_jwks,
           config: {
             inputs: {
               auth_token_headers_json: { name: :order_dispatch_auth_token_headers_json }
             },
             outputs: {
               crd_jwks_json: { name: :order_dispatch_crd_jwks_json },
               crd_jwks_keys_json: { name: :order_dispatch_crd_jwks_keys_json }
             }
           }
      test from: :crd_token_header,
           config: {
             inputs: {
               auth_token_headers_json: { name: :order_dispatch_auth_token_headers_json },
               crd_jwks_keys_json: { name: :order_dispatch_crd_jwks_keys_json }
             },
             outputs: {
               auth_tokens_jwk_json: { name: :order_dispatch_auth_tokens_jwk_json }
             }
           }
      test from: :crd_token_payload,
           config: {
             options: { hook_path: ORDER_DISPATCH_PATH },
             inputs: {
               auth_tokens: { name: :order_dispatch_auth_tokens },
               auth_tokens_jwk_json: { name: :order_dispatch_auth_tokens_jwk_json }
             }
           }

      test from: :crd_hook_request_required_fields,
           config: {
             options: {
               hook_name: 'order-dispatch'
             }
           }
      test from: :crd_hook_request_optional_fields,
           config: {
             options: {
               hook_name: 'order-dispatch'
             },
             outputs: {
               client_fhir_server: { name: :order_dispatch_client_fhir_server },
               client_access_token: { name: :order_dispatch_client_access_token }
             }
           }

      test from: :crd_hook_request_valid_context,
           config: {
             inputs: {
               client_fhir_server: { name: :order_dispatch_client_fhir_server },
               client_access_token: { name: :order_dispatch_client_access_token }
             },
             options: { hook_name: 'order-dispatch' }
           }

      test from: :crd_hook_request_valid_prefetch,
           config: {
             options: { hook_name: 'order-dispatch' }
           }

      test from: :crd_card_display_attest_test,
           config: {
             inputs: {
               selected_response_types: { name: :order_dispatch_selected_response_types }
             }
           }
    end

    group do
      title 'order-sign'
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

      optional
      run_as_group

      config(
        inputs: {
          custom_response: { name: :order_sign_custom_response }
        }
      )

      test from: :crd_submitted_response_validation,
           config: {
             options: {
               hook_name: 'order-sign'
             }
           }

      test from: :crd_order_sign_request

      test from: :crd_decode_auth_token,
           config: {
             options: {
               hook_name: 'order-sign'
             },
             outputs: {
               auth_tokens: { name: :order_sign_auth_tokens },
               auth_token_payloads_json: { name: :order_sign_auth_token_payloads_json },
               auth_token_headers_json: { name: :order_sign_auth_token_headers_json }
             }
           }
      test from: :crd_retrieve_jwks,
           config: {
             inputs: {
               auth_token_headers_json: { name: :order_sign_auth_token_headers_json }
             },
             outputs: {
               crd_jwks_json: { name: :order_sign_crd_jwks_json },
               crd_jwks_keys_json: { name: :order_sign_crd_jwks_keys_json }
             }
           }
      test from: :crd_token_header,
           config: {
             inputs: {
               auth_token_headers_json: { name: :order_sign_auth_token_headers_json },
               crd_jwks_keys_json: { name: :order_sign_crd_jwks_keys_json }
             },
             outputs: {
               auth_tokens_jwk_json: { name: :order_sign_auth_tokens_jwk_json }
             }
           }
      test from: :crd_token_payload,
           config: {
             options: { hook_path: ORDER_SIGN_PATH },
             inputs: {
               auth_tokens: { name: :order_sign_auth_tokens },
               auth_tokens_jwk_json: { name: :order_sign_auth_tokens_jwk_json }
             }
           }

      test from: :crd_hook_request_required_fields,
           config: {
             options: {
               hook_name: 'order-sign'
             }
           }
      test from: :crd_hook_request_optional_fields,
           config: {
             options: {
               hook_name: 'order-sign'
             },
             outputs: {
               client_fhir_server: { name: :order_sign_client_fhir_server },
               client_access_token: { name: :order_sign_client_access_token }
             }
           }

      test from: :crd_hook_request_valid_context,
           config: {
             inputs: {
               client_fhir_server: { name: :order_sign_client_fhir_server },
               client_access_token: { name: :order_sign_client_access_token }
             },
             options: { hook_name: 'order-sign' }
           }

      test from: :crd_hook_request_valid_prefetch,
           config: {
             options: { hook_name: 'order-sign' }
           }

      test from: :crd_card_display_attest_test,
           config: {
             inputs: {
               selected_response_types: { name: :order_sign_selected_response_types }
             }
           }
    end
  end
end
