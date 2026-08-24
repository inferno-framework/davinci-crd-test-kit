require_relative 'user_access_level/access_level_receive_request_test'
require_relative 'user_access_level/access_level_same_scenario_test'
require_relative 'user_access_level/access_level_api_access_test'
require_relative 'user_access_level/access_level_prefetch_scope_test'
require_relative '../../cross_suite/tags'

module DaVinciCRDTestKit
  module V221
    # ID-216: "User Access Level Scoping" scenario group. Verifies that payer data access exposed
    # to a CDS Service during hook invocation is scoped to the authorized access level of the EHR
    # user, by comparing a full-access run against a limited-access run of the same scenario.
    class ClientUserAccessLevelGroup < Inferno::TestGroup
      title 'User Access Level Scoping'
      id :crd_v221_client_user_access_level
      description <<~DESCRIPTION
        This group verifies that access to payer data exposed to a CDS Service during hook
        invocation is scoped to the authorized access level of the EHR user, rather than relying
        solely on attestation. Testers will place the same order, appointment, or encounter twice:
        once as an EHR user with full access, and again as an EHR user with limited access, and
        provide a reference to a resource that the full-access user is expected to be able to read
        and the limited-access user is expected to be denied. Inferno will use the access token
        supplied in each hook request to read that resource and will compare the two runs to
        confirm that FHIR API access - and, where the tester's data supports it, prefetch data -
        differs according to the user's access level.

        Hook requests made during these tests will not be checked for conformance or included in
        the cross-hook analyses around must support and other coverage requirements.
      DESCRIPTION

      run_as_group

      input_order :access_level_target_reference

      # each instance configures its own crd_interaction_group tag so the two runs' hook requests
      # (and the FHIR reads triggered by them) can be told apart during analysis.
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
