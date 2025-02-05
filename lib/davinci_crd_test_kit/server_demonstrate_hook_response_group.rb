require_relative 'server_tests/service_call_test'
require_relative 'server_tests/service_request_required_fields_validation_test'
require_relative 'server_tests/service_request_context_validation_test'
require_relative 'server_tests/service_request_optional_fields_validation_test'
require_relative 'server_tests/service_response_validation_test'
require_relative 'server_tests/card_optional_fields_validation_test'
require_relative 'server_tests/external_reference_card_validation_test'
require_relative 'server_tests/launch_smart_app_card_validation_test'
require_relative 'server_tests/instructions_card_received_test'
require_relative 'server_tests/coverage_information_system_action_received_test'
require_relative 'server_tests/coverage_information_system_action_validation_test'
require_relative 'server_tests/form_completion_response_validation_test'
require_relative 'server_tests/create_or_update_coverage_info_response_validation_test'

module DaVinciCRDTestKit
  class ServeDemonstrateHookResponseGroup < Inferno::TestGroup
    title 'Demonstrate A Hook Response'
    id :crd_server_demonstrate_hook_response
    description %(
      This group of tests allows the system to demonstrate its ability to respond to a CRD Hook invocation
      and return a valid response. Inferno will use the provided request body and will either use the provided service
      id or infer one from the hook indicated in the request and the server's discovery response.
      It ensures that the user-provided requests and the server's responses are both
      valid as per the requirements described in the [CRD IG section](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html)
      and the [CDS Hooks](https://cds-hooks.hl7.org/) hook specification for the corresponding hook.
    )

    config options: { hook_name: 'any' }
    run_as_group

    test from: :crd_service_call_test,
         config: {
           inputs: {
             service_ids: {
               name: :any_hook_service_ids,
               title: 'Service id to use for the "Demonstrate a Hook Response" test',
               description: %(
                If blank, Inferno will attempt to infer the service id to use by finding a service entry in the
                Discovery response for the hook indicated in the provided request body. If it cannot be inferred,
                the tests will be skipped.
               ),
               optional: true
             },
             service_request_bodies: {
               name: :any_hook_request_body,
               title: 'Request body to use for the "Demonstrate a Hook Response" test',
               description: %(
                Provide a single JSON request body to submit for the hook invocation. The type of hook invoked
                will be inferred based on the `hook` element in the request.
              )
             }
           }
         }

    test from: :crd_service_request_required_fields_validation,
         config: {
           outputs: {
             contexts: {
               name: :any_hook_contexts
             }
           }
         }
    test from: :crd_service_request_context_validation,
         config: {
           inputs: {
             contexts: {
               name: :any_hook_contexts
             },
             request_body: {
               name: :any_hook_request_body
             }
           }
         }
    test from: :crd_service_response_validation,
         config: {
           outputs: {
             valid_cards: {
               name: :any_hook_valid_cards
             },
             valid_system_actions: {
               name: :any_hook_valid_system_actions
             }
           }
         }
  end
end
