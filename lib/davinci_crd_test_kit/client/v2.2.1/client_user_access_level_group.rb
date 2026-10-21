require_relative 'user_access_level/access_level_receive_request_test'
require_relative 'user_access_level/access_level_same_scenario_test'
require_relative 'user_access_level/access_level_api_access_test'
require_relative 'user_access_level/access_level_prefetch_scope_test'
require_relative '../../cross_suite/tags'

module DaVinciCRDTestKit
  module V221
    class ClientUserAccessLevelGroup < Inferno::TestGroup
      title 'User Access Level Scoping'
      id :crd_v221_client_user_access_level
      description <<~DESCRIPTION
        This group verifies that during a CDS Service hook invocation access to data on
        the CRD client's FHIR server is scoped to the authorized access level of the EHR
        user when the hook is invoked. Testers will invoke a hook twice, each time with consistent
        content (e.g., an order for the same service): once as an EHR user with full access, and
        again as an EHR user with limited access. Testers will provide a reference to a resource
        that the full-access user is expected to be able to access while the limited-access user
        cannot. If possible, the resource should be in the set of prefetched data that Inferno
        requests. Inferno will use the access token supplied in each hook request to read that
        resource and will compare the two runs to confirm that data available to the payer differs
        according to the user's access level, both in provided prefetch data and in what can be
        retrieved using the access token provided in the hook request.

        Hook requests made during these tests will not be checked for conformance beyond scenario
        requirements for confirming that both hook requests contain consistent content. The requests
        will not be included in the cross-hook analyses around must support and other coverage
        requirements.
      DESCRIPTION

      run_as_group

      input_order :access_level_target_reference

      config(
        options: {
          hook_name: ANY_HOOK_TAG,
          include_in_cross_hook_analysis: false
        }
      )

      # only the interaction group differs, so that the two runs' requests can be told apart
      test from: :crd_v221_access_level_receive_request, id: :crd_v221_access_level_receive_request_full do
        title 'CRD client invokes a hook as a full-access user'
        description %(
          During this test, Inferno will wait while the CRD client makes a single hook request of any
          type, made while the tester is signed in as a user with full access.

          Inferno will use the access token in the request to attempt to read the resource
          referenced in the **Target Resource Reference** input and will return a
          [mocked](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
          coverage-information response. The details of the request and its response are not
          evaluated or checked for conformance in this test. The test will automatically continue
          once Inferno has received a single valid hook request.
        )
        config options: { crd_interaction_group: ACCESS_LEVEL_FULL_GROUP_TAG }
      end

      test from: :crd_v221_access_level_receive_request, id: :crd_v221_access_level_receive_request_limited do
        title 'CRD client invokes the same hook as a limited-access user'
        description %(
          During this test, Inferno will wait while the CRD client makes a single hook request, made
          while the tester is signed in as a user with limited access. It must invoke the same hook
          for the same patient and the same order(s), appointment(s), or encounter as the full-access
          request made during the previous test.

          Inferno will use the access token in the request to attempt to read the resource
          referenced in the **Target Resource Reference** input and will return a
          [mocked](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
          coverage-information response. The details of the request and its response are not
          evaluated or checked for conformance in this test. The test will automatically continue
          once Inferno has received a single valid hook request.
        )
        config options: { crd_interaction_group: ACCESS_LEVEL_LIMITED_GROUP_TAG }
      end

      test from: :crd_v221_access_level_same_scenario
      test from: :crd_v221_access_level_api_access
      test from: :crd_v221_access_level_prefetch_scope
    end
  end
end
