require_relative 'multiple_payers/client_multiple_payers_workflow_test'
require_relative 'multiple_payers/client_multiple_payers_request_verification_test'

module DaVinciCRDTestKit
  module V221
    class ClientMultiplePayersHookGroup < Inferno::TestGroup
      title 'Multiple Payers'
      id :crd_v221_client_multiple_payers_hook
      description <<~DESCRIPTION
        The CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/deviations.html#hook-invocation-for-multi-coverage-patients)
        that clients request coverage information details from at most one payer for each request.
        During this scenario the tester will perform a workflow that triggers a hook invocation
        for a patient that has two coverages each associated with a payer tied to a different Inferno
        simulated CRD endpoint. Inferno will verify that the hook requests it receives solicit coverage
        information from only one of them. This can be accomplished by either making a hook request
        to only the payer associated with the primary coverage, or by making a hook request
        to both and explicitly disabling the return of coverage information details on the request to
        the payer associated with the secondary coverage using the [configuration option
        extension](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/deviations.html#ci-c-dev-5)
        which payers are required to support.

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
