require_relative '../interaction/server_invoke_hook_single_request_test'
require_relative 'coverage_info_reason_test'

module DaVinciCRDTestKit
  module V221
    class NoMemberFoundGroup < Inferno::TestGroup
      title 'No Member Found'
      id :crd_v221_server_no_member_found_group
      description %(
        This group of tests allows the system to demonstrate its ability to respond to a CRD Hook invocation
        with a `not-covered` coverage determination when it is unable to resolve the patient for a
        non-technical reason.

        For these tests, provide a hook request body that represents a patient/member the CRD Server cannot
        resolve for a non-technical reason.

        The tests then verify that a Coverage Information systemAction is received with `not-covered` coverage
        for `no-member-found` reasons.
      )

      config options: { hook_name: NO_MEMBER_FOUND_TAG }
      run_as_group

      group do
        title 'Interaction'

        test from: :crd_v221_server_invoke_hook_single_request_test,
             title: 'Inferno invokes the selected hook to elicit unresolved member response',
             description: <<~DESCRIPTION,
               This test initiates a POST request to a specified CDS Service using the JSON body provided
               by the user. The request body should represent an unrecognized member.
             DESCRIPTION
             config: {
               inputs: {
                 service_ids: {
                   name: :no_member_found_service_ids,
                   title: 'Service id to use for the "No Member Found" test',
                   description: %(
                     If blank, Inferno will attempt to infer the service id to use by finding a service entry
                     in the Discovery response for the hook indicated in the provided request body. If it
                     cannot be inferred, the tests will be skipped.
                   )
                 },
                 service_request_bodies: {
                   name: :no_member_found_request_body,
                   title: 'Request body to use for the "No Member Found" test',
                   description: %(
                     Provide a single JSON request body to submit for the hook invocation. The type of hook
                     invoked will be inferred based on the `hook` element in the request. The body should be
                     constructed so that the CRD Server is unable to resolve the patient/member.
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
                   name: :no_member_found_contexts
                 }
               }
             }
        test from: :crd_v221_service_request_context_validation,
             config: {
               inputs: {
                 contexts: {
                   name: :no_member_found_contexts
                 },
                 request_body: {
                   name: :no_member_found_request_body
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
                   name: :no_member_found_valid_cards
                 },
                 valid_system_actions: {
                   name: :no_member_found_valid_system_actions
                 }
               }
             }
        test from: :crd_v221_coverage_info_system_action_received,
             config: {
               inputs: {
                 valid_system_actions: {
                   name: :no_member_found_valid_system_actions
                 }
               },
               outputs: {
                 coverage_info: {
                   name: :no_member_found_coverage_info
                 }
               }
             }
        test from: :crd_v221_coverage_info_system_action_validation,
             config: {
               inputs: {
                 coverage_info: {
                   name: :no_member_found_coverage_info
                 }
               }
             }
        test from: :crd_v221_coverage_info_reason,
             title: 'Coverage Information responses have not-covered coverage for no-member-found reason',
             description: <<~DESCRIPTION,
               This test verifies that the Coverage Information responses received contain Coverage Information
               extensions with `not-covered` coverage and a `no-member-found` reason.
             DESCRIPTION
             config: {
               inputs: {
                 coverage_info: {
                   name: :no_member_found_coverage_info
                 }
               },
               options: {
                 expected_coverage_code: 'not-covered',
                 expected_reason_code: 'no-member-found'
               }
             },
             verifies_requirements: [
               'hl7.fhir.us.davinci-crd_2.2.1@resp-44'
             ]
      end
    end
  end
end
