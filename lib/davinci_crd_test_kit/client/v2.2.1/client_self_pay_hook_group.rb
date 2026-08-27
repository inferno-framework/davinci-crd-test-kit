require_relative 'self_pay/client_self_pay_workflow_test'
require_relative 'self_pay/client_self_pay_no_request_test'

module DaVinciCRDTestKit
  module V221
    class ClientSelfPayHookGroup < Inferno::TestGroup
      title 'Self-Pay'
      id :crd_v221_client_self_pay_hook
      description <<~DESCRIPTION
        The CRD IG requires clients to invoke hooks on payer services only when the patient
        record indicates active coverage with the payer associated with the service and there
        is no recorded indication that the patient intends to bypass insurance coverage, i.e.,
        the service or product is not flagged as 'patient-pay'. During this scenario the tester
        performs a workflow that would normally trigger a hook request, but for a service or
        product that the patient has indicated they intend to self-pay for, and Inferno
        verifies that no hook requests are made.

        Any hook requests made during these tests will not be checked for conformance
        or included in the cross-hook analyses around must support and other coverage requirements.
      DESCRIPTION

      run_as_group

      config(
        options: {
          hook_name: ANY_HOOK_TAG,
          crd_interaction_group: SELF_PAY_GROUP_TAG,
          include_in_cross_hook_analysis: false
        }
      )

      test from: :crd_v221_client_self_pay_workflow
      test from: :crd_v221_client_self_pay_no_request
    end
  end
end
