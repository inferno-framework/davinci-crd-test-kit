require_relative 'multiple_payers/client_multiple_payers_workflow_test'
require_relative 'multiple_payers/client_multiple_payers_request_verification_test'

module DaVinciCRDTestKit
  module V221
    class ClientMultiplePayersHookGroup < Inferno::TestGroup
      title 'Multiple Payers'
      id :crd_v221_client_multiple_payers_hook
      description <<~DESCRIPTION
        The CRD IG constrains how clients invoke hooks when a patient has multiple active coverages
        that could be relevant to the current action: clients must select from those coverages which
        is most likely to be primary and solicit coverage information from only that one payer, and
        if they invoke CRD on other payers, response types that return coverage information must be
        disabled for those 'likely secondary' payers. During this scenario the tester will perform a
        workflow that triggers hook invocation for a patient that has two coverages associated with
        two different payers, each associated with one of Inferno's simulated CRD servers, and
        Inferno will verify that the requests it receives solicit coverage information from only one
        of them.

        Hook requests made during these tests will not be checked for conformance
        or included in the cross-hook analyses around must support and other coverage requirements.
      DESCRIPTION

      run_as_group

      config(
        options: {
          hook_name: ANY_HOOK_TAG,
          crd_interaction_group: MULTIPLE_PAYERS_GROUP_TAG,
          include_in_cross_hook_analysis: false
        }
      )

      test from: :crd_v221_client_multiple_payers_workflow
      test from: :crd_v221_client_multiple_payers_request_verification
    end
  end
end
