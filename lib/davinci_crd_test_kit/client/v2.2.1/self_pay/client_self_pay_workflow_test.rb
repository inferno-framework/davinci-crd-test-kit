require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    class ClientSelfPayWorkflowTest < Inferno::Test
      include ClientURLs

      id :crd_v221_client_self_pay_workflow
      title 'Client performs a self-pay workflow'
      description %(
        During this test, the tester will perform a self-pay scenario in which a patient has indicated
        that they will pay for a service instead of asking their insurance to cover it. Because there
        is a recorded indication that the patient intends to bypass insurance coverage, the client
        is required to not invoke any hooks that would send details of the service to the payer.
        The scenario must include an action related to the service that would normally trigger a
        hook request and Inferno will verify that no hook requests are received.
      )

      input :cds_jwt_iss,
            title: 'CRD JWT Issuer',
            description: %(
              Value of the `iss` claim that must be present in the JWT used to authorize the client's hook
              request sent as the Bearer token in the `Authorization` header.
              Run or re-run the "Registration" group to set or change this value.
            ),
            locked: true
      output :continuation_url

      run do
        identifier = cds_jwt_iss
        continuation_url = "#{resume_pass_url}?token=#{identifier}"
        output(continuation_url:)

        wait(
          identifier:,
          message: %(
            **Self-Pay Workflow Test**:

            Perform a workflow that would normally trigger a hook request, such as one
            performed during previous tests, but for a service or product where the patient
            record contains an indication that the patient intends to self-pay. The client must
            not send any hook requests to Inferno during the workflow.

            By [clicking here](#{continuation_url}) I attest that a user completed a workflow
            in the client system that would normally trigger a hook request for a service that
            has been marked as self-pay.

            If Inferno receives a hook request, this test will automatically continue
            and the next test will fail.
          )
        )
      end
    end
  end
end
