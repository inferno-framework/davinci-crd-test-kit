require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    class ClientSelfPayWorkflowTest < Inferno::Test
      include ClientURLs

      id :crd_v221_client_self_pay_workflow
      title 'Client performs a self-pay workflow'
      description %(
        During this test, Inferno will wait while the tester performs a workflow that would
        normally trigger a hook request, but for a service or product that the patient record
        indicates the patient intends to pay for themselves. Because there is a recorded
        indication that the patient intends to bypass insurance coverage, the client is not
        expected to invoke any hooks and Inferno does not expect to receive any requests.
        Once the workflow is complete, the tester will click a link to continue the test.

        If the client does make a hook request, Inferno will return a fixed [mocked response](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
        containing a coverage information system action, which testers cannot change, and the
        test will automatically continue. The details of the request and its response do not
        matter for the purposes of this test and they will not be evaluated, checked for
        conformance, or included in cross-hook evaluations, but any request received will
        cause the next test to fail.
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
            record contains an indication that the patient intends to self-pay. Because the
            service or product is flagged as 'patient-pay', the client must not invoke any
            hooks.

            [Click here](#{continuation_url}) once the workflow is complete.

            If Inferno receives a hook request, this test will automatically continue
            and the next test will fail.
          )
        )
      end
    end
  end
end
