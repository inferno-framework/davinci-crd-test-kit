require_relative '../client_urls'
require_relative '../../client_input_helper'

module DaVinciCRDTestKit
  module V221
    class ClientSelfPayWorkflowTest < Inferno::Test
      include ClientURLs

      id :crd_v221_client_self_pay_workflow
      title 'CRD client does not invoke hooks when the patient intends to bypass insurance coverage'
      description %(
        The CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/deviations.html#ci-c-dev-26)
        that CRD clients only invoke hooks on payer services where the patient record indicates
        active coverage with the payer associated with the service and where there is no recorded
        indication the patient intends to bypass insurance coverage, i.e., the service or product
        is not flagged as 'self-pay' or 'patient-pay'.

        During this test, the tester will perform a self-pay scenario in which a patient has indicated
        that they will pay for a product or service instead of asking their insurance to cover it.
        The scenario must include an action related to the product or service that would normally
        trigger a hook request. The test will fail immediately if Inferno receives a hook request
        while the tester takes the necessary steps in the CRD client. If the tester's actions in the
        CRD client complete without triggering any hook requests to Inferno, the tester will provide
        an attestation to that effect to complete the test.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@dev-26-B'

      input :cds_jwt_iss,
            title: 'CRD JWT Issuer',
            description: ClientInputHelper.locked_cds_jwt_iss_description,
            locked: true
      output :continuation_url
      flag_as_tester_initiated_exchange
      flag_as_attestation

      run do
        identifier = cds_jwt_iss
        continuation_url = resume_pass_url_for(identifier)
        output(continuation_url:)

        wait(
          identifier:,
          message: %(
            #### Self-Pay Scenario Test

            Perform actions in the CRD client that would normally trigger a hook request, such as one
            performed during previous tests, but for a service or product where the patient
            record contains an indication that the patient intends to self-pay. The CRD client must
            not send any hook requests to Inferno during the workflow.

            Once all necessary actions are complete, [click here](#{continuation_url}) to attest that
            the steps that would normally trigger a hook request have been completed for a service
            marked as self-pay.

            If Inferno receives a hook request, this test will immediately fail.
          )
        )
      end
    end
  end
end
