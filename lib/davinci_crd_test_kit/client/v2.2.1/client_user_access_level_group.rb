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
        This group verifies that access to client data during a CDS Service hook invocation
        is scoped to the authorized access level of the EHR user when the hook is
        invoked. Testers will invoke a hook twice, each time with consistent content (e.g., an
        order for the same service): once as an EHR user with full access, and again as an
        EHR user with limited access. Testers will provide a reference to a resource that the
        full-access user is expected to be able to access while the limited-access user cannot.
        Inferno will use the access token supplied in each hook request to read that resource and
        will compare the two runs to confirm that data available to the payer differs according to
        the user's access level, both in provided prefetch data and in what can be retrieved using
        the access token provided in the hook request.

        Hook requests made during these tests will not be checked for conformance beyond scenario
        requirements for confirming that both hook requests contain consistent content. The requests
        will not be included in the cross-hook analyses around must support and other coverage
        requirements.
      DESCRIPTION

      run_as_group

      input_order :access_level_target_reference

      test from: :crd_v221_access_level_receive_request, id: :crd_v221_access_level_receive_request_full do
        title 'Client invokes a hook as a full-access user'
        config options: {
          crd_interaction_group: ACCESS_LEVEL_FULL_GROUP_TAG,
          include_in_cross_hook_analysis: false,
          hook_name: ANY_HOOK_TAG
        }
      end

      test from: :crd_v221_access_level_receive_request, id: :crd_v221_access_level_receive_request_limited do
        title 'Client invokes the same hook as a limited-access user'
        config options: {
          crd_interaction_group: ACCESS_LEVEL_LIMITED_GROUP_TAG,
          include_in_cross_hook_analysis: false,
          hook_name: ANY_HOOK_TAG
        }
      end

      test from: :crd_v221_access_level_same_scenario
      test from: :crd_v221_access_level_api_access
      test from: :crd_v221_access_level_prefetch_scope
    end
  end
end
