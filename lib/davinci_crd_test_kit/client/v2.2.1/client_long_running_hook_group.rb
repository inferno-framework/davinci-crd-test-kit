require_relative 'long_running/client_long_running_receive_request_test'
require_relative 'long_running/client_skip_long_running_attestation_test'

module DaVinciCRDTestKit
  module V221
    class ClientLongRunningHookGroup < Inferno::TestGroup
      title 'Long-running Hook Request'
      id :crd_v221_client_long_running_hook
      description <<~DESCRIPTION
        When a hook invocation runs long, the CRD IG requires systems to provide
        users with a way to bypass the hook and continue their workflow.

        Hook requests made during these tests will not be checked for conformance
        or included in the cross-hook analyses around must support and other coverage requirements.
      DESCRIPTION

      run_as_group

      input_order :cds_jwt_iss

      config(
        options: {
          hook_name: ANY_HOOK_TAG,
          crd_test_group: LONG_RUNNING_GROUP_TAG
        }
      )

      test from: :crd_v221_client_long_running_receive_request
      test from: :crd_v221_client_skip_long_running_attestation_test
    end
  end
end
