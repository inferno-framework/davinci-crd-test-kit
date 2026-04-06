require_relative '../../cross_suite/tags'
require_relative 'verify_request/service_call_test'
require_relative 'verify_request/service_request_required_fields_validation_test'
require_relative 'verify_request/service_request_optional_fields_validation_test'
require_relative 'verify_request/service_request_context_validation_test'
require_relative 'verify_response/service_response_validation_test'
require_relative 'verify_response/card_optional_fields_validation_test'
require_relative 'verify_response/external_reference_card_validation_test'
require_relative 'verify_response/coverage_information_system_action_received_test'
require_relative 'verify_response/coverage_information_system_action_validation_test'
require_relative 'verify_response/instructions_card_received_test'
require_relative 'verify_response/form_completion_response_validation_test'
require_relative 'verify_response/launch_smart_app_card_validation_test'
require_relative 'verify_response/create_or_update_coverage_info_response_validation_test'

module DaVinciCRDTestKit
  module V220
    class ServerAppointmentBookGroup < Inferno::TestGroup
      title 'appointment-book'
      id :crd_v220_server_appointment_book
      description %(
        This group of tests invokes the appointment-book hook and ensures that
        the user-provided requests are valid as per the requirements described
        in the [CRD IG section on appointment-book hook](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#appointment-book)
        and the [CDS Hooks specification section on appointment-book context](https://cds-hooks.hl7.org/hooks/appointment-book/2023SepSTU1Ballot/appointment-book/).
        It also ensures that the contents of the server's response are valid as per the requirements described in
        the [CRD IG section on appointment-book hook](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#appointment-book)
        and the [CDS Hooks section on CDS Service Response](https://cds-hooks.hl7.org/2.0/#cds-service-response).

        The [CRD IG section on appointment-book hook](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#appointment-book)
        states that "servers SHALL, at minimum, support returning and processing the Coverage Information
        system action for all invocations of this hook."

        This group includes tests to validate the following CRD response types:
        - [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information)
        - [Create or update coverage information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#create-or-update-coverage-information)\
        - optional
        - [External Reference](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#external-reference) - optional
        - [Instructions](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#instructions) - optional
        - [Launch SMART application](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#launch-smart-application) -
        optional
        - [Request form completion](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#request-form-completion) -
        optional
      )
      # verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@164', 'hl7.fhir.us.davinci-crd_2.0.1@168',
      #                       'hl7.fhir.us.davinci-crd_2.0.1@170', 'hl7.fhir.us.davinci-crd_2.0.1@184'

      config options: { hook_name: APPOINTMENT_BOOK_TAG }
      run_as_group

      test from: :crd_v220_service_call_test,
           config: {
             inputs: {
               service_ids: {
                 name: :appointment_book_service_ids,
                 title: 'Service id for the service that implements the `appointment-book` hook'
               },
               service_request_bodies: {
                 name: :appointment_book_request_bodies,
                 title: 'Request body or bodies for invoking the `appointment-book` hook'
               }
             }
           }

      test from: :crd_v220_service_request_required_fields_validation,
           config: {
             outputs: {
               contexts: {
                 name: :appointment_book_contexts
               }
             }
           }
      test from: :crd_v220_service_request_context_validation,
           config: {
             inputs: {
               contexts: {
                 name: :appointment_book_contexts
               }
             }
           }
      test from: :crd_v220_service_request_optional_fields_validation
      test from: :crd_v220_service_response_validation,
           config: {
             outputs: {
               valid_cards: {
                 name: :appointment_book_valid_cards
               },
               valid_system_actions: {
                 name: :appointment_book_valid_system_actions
               }
             }
           }
      test from: :crd_v220_card_optional_fields_validation,
           config: {
             inputs: {
               valid_cards: {
                 name: :appointment_book_valid_cards
               }
             },
             outputs: {
               valid_cards_with_links: {
                 name: :appointment_book_valid_cards_with_links
               },
               valid_cards_with_suggestions: {
                 name: :appointment_book_valid_cards_with_suggestions
               }
             }
           }
      test from: :crd_v220_external_reference_card_validation,
           config: {
             inputs: {
               valid_cards_with_links: {
                 name: :appointment_book_valid_cards_with_links
               }
             }
           }
      test from: :crd_v220_launch_smart_app_card_validation,
           config: {
             inputs: {
               valid_cards_with_links: {
                 name: :appointment_book_valid_cards_with_links
               }
             }
           }
      test from: :crd_v220_valid_instructions_card_received,
           config: {
             inputs: {
               valid_cards: {
                 name: :appointment_book_valid_cards
               }
             }
           }
      test from: :crd_v220_coverage_info_system_action_received,
           config: {
             inputs: {
               valid_system_actions: {
                 name: :appointment_book_valid_system_actions
               }
             },
             outputs: {
               coverage_info: {
                 name: :appointment_book_coverage_info
               }
             }
           }
      test from: :crd_v220_coverage_info_system_action_validation,
           config: {
             inputs: {
               coverage_info: {
                 name: :appointment_book_coverage_info
               }
             }
           }
      test from: :crd_v220_request_form_completion_response_validation,
           config: {
             inputs: {
               valid_system_actions: {
                 name: :appointment_book_valid_system_actions
               },
               valid_cards_with_suggestions: {
                 name: :appointment_book_valid_cards_with_suggestions
               }
             }
           }
      test from: :crd_v220_create_or_update_coverage_info_response_validation,
           config: {
             inputs: {
               valid_system_actions: {
                 name: :appointment_book_valid_system_actions
               },
               valid_cards_with_suggestions: {
                 name: :appointment_book_valid_cards_with_suggestions
               }
             }
           }
    end
  end
end
