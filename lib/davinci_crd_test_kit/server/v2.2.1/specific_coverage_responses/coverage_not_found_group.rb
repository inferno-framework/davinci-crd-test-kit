require_relative '../interaction/server_invoke_hook_single_request_test'
require_relative 'coverage_info_reason_test'

module DaVinciCRDTestKit
  module V221
    class CoverageNotFoundGroup < Inferno::TestGroup
      title 'Coverage Not Found'
      id :crd_v221_server_coverage_not_found_group
      description %(
        This group of tests allows the system to demonstrate its ability to respond to a CRD Hook invocation
        with a `not-covered` coverage determination when the patient can be resolved but coverage cannot be found
        or cannot be resolved to a single coverage.

        For these tests, provide a hook request body that represents a resolvable patient for whom the CRD Server
        cannot find coverage or cannot resolve to a single coverage. The tests then verify that a Coverage
        Information systemAction is received with `not-covered` coverage for `coverage-not-found` reason.
      )

      config options: { hook_name: COVERAGE_NOT_FOUND_TAG }
      run_as_group

      group do
        title 'Interaction'

        test from: :crd_v221_server_invoke_hook_single_request_test,
             title: 'Inferno invokes the selected hook to elicit coverage not found response',
             description: <<~DESCRIPTION,
               This test initiates a POST request to a specified CDS Service using the JSON body provided
               by the user. The request body should represent a resolvable patient for whom coverage cannot be
               found or cannot be resolved to a single coverage.
             DESCRIPTION
             config: {
               inputs: {
                 service_ids: {
                   name: :coverage_not_found_service_ids,
                   title: 'Service id to use for the "Coverage Not Found" test',
                   description: %(
                     If blank, Inferno will attempt to infer the service id to use by finding a service entry
                     in the Discovery response for the hook indicated in the provided request body. If it
                     cannot be inferred, the tests will be skipped.
                   )
                 },
                 service_request_bodies: {
                   name: :coverage_not_found_request_body,
                   title: 'Request body to use for the "Coverage Not Found" test',
                   description: %(
                     Provide a single JSON request body to submit for the hook invocation. The type of hook
                     invoked will be inferred based on the `hook` element in the request. The body should be
                     constructed so that it represents a resolvable patient for whom coverage cannot be found.
                   )
                 }
               }
             }
      end

      group do
        title 'Requests'
        simulation_verification

        test from: :crd_v221_service_request_required_fields_validation,
             config: {
               outputs: {
                 contexts: {
                   name: :coverage_not_found_contexts
                 }
               }
             }
        test from: :crd_v221_service_request_context_validation,
             config: {
               inputs: {
                 contexts: {
                   name: :coverage_not_found_contexts
                 },
                 request_body: {
                   name: :coverage_not_found_request_body
                 }
               }
             }
      end

      group do
        title 'Responses'

        test from: :crd_v221_service_response_validation,
             config: {
               outputs: {
                 valid_cards: {
                   name: :coverage_not_found_valid_cards
                 },
                 valid_system_actions: {
                   name: :coverage_not_found_valid_system_actions
                 }
               }
             }
        test from: :crd_v221_coverage_info_system_action_received,
             config: {
               inputs: {
                 valid_system_actions: {
                   name: :coverage_not_found_valid_system_actions
                 }
               },
               outputs: {
                 coverage_info: {
                   name: :coverage_not_found_coverage_info
                 }
               }
             }
        test from: :crd_v221_coverage_info_system_action_validation,
             config: {
               inputs: {
                 coverage_info: {
                   name: :coverage_not_found_coverage_info
                 }
               }
             }
        test from: :crd_v221_coverage_info_reason,
             title: 'Coverage Information responses have not-covered coverage for coverage-not-found reason',
             description: <<~DESCRIPTION,
               This test verifies that the Coverage Information responses received contain Coverage Information
               extensions with `not-covered` coverage and a `coverage-not-found` reason.
             DESCRIPTION
             config: {
               inputs: {
                 coverage_info: {
                   name: :coverage_not_found_coverage_info
                 }
               },
               options: {
                 expected_coverage_code: 'not-covered',
                 expected_reason_code: 'coverage-not-found'
               }
             },
             verifies_requirements: [
               'hl7.fhir.us.davinci-crd_2.2.1@resp-45'
             ]
      end
    end
  end
end
