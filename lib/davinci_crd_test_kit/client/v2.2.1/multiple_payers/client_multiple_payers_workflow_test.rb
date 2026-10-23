require_relative '../../client_wait_messages'
require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    class ClientMultiplePayersWorkflowTest < Inferno::Test
      include ClientURLs
      include DaVinciCRDTestKit::ClientWaitMessages

      id :crd_v221_client_multiple_payers_workflow
      title 'CRD client performs a workflow for a patient with multiple payer coverages'
      description %(
        During this test, the tester will perform a workflow that triggers hook invocations for a
        request on a patient that has two active coverages associated with two different payers,
        each associated with one of Inferno's simulated CRD servers. The CRD client is expected to solicit
        coverage information from only the payer associated with the coverage most likely to be primary
        and may also invoke the hook on the other payer with coverage information disabled using
        the `coverage-info` key within the `davinci-crd.configuration` extension. Inferno will return
        at most a fixed [mocked response](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
        containing only a coverage information system action, but not if the hook request disables
        coverage information responses through the configuration extension. Inferno will wait until
        the tester acknowledges that all hook requests triggered by the workflow have been sent.
      )

      input :cds_jwt_iss,
            title: 'CRD JWT Issuer',
            description: %(
              Value of the `iss` claim that must be present in the JWT used to authorize the CRD client's hook
              request sent as the Bearer token in the `Authorization` header.
              Run or re-run the "Registration" group to set or change this value.
            ),
            locked: true
      input :complete_prefetch_service_organization_id,
            title: 'Complete Prefetch Service Organization id',
            description: %(
              The FHIR Organization id associated with Inferno's simulated
              complete prefetch CRD server. One of the patient's two Coverages must reference
              this Organization as its payer.
              Re-run the "Registration" group to provide this detail.
            ),
            type: 'text',
            optional: true,
            locked: true
      input :subset_prefetch_service_organization_id,
            title: 'Subset Prefetch Service Organization id',
            description: %(
              The FHIR Organization id associated with Inferno's simulated
              subset prefetch CRD server. One of the patient's two Coverages must reference
              this Organization as its payer.
              Re-run the "Registration" group to provide this detail.
            ),
            type: 'text',
            optional: true,
            locked: true
      output :continuation_url

      def payer_organization_note(organization_id)
        return '' if organization_id.blank?

        " (payer Organization id: `#{organization_id}`)"
      end

      run do
        identifier = cds_jwt_iss
        continuation_url = resume_pass_url_for(identifier)
        output(continuation_url:)

        wait(
          identifier:,
          message: wait_message
        )
      end

      def wait_message
        <<~MESSAGE
          #### Multiple Payers Scenario Test

          Perform actions in the CRD client that trigger hook invocation(s), such as
          one performed during previous tests, for a patient that has two active
          coverages associated with two different payers, each associated with one
          of the two Inferno simulated CRD service endpoints.

          Once all necessary actions are complete, [click here](#{continuation_url}) to attest
          that the CRD client triggered hook invocation(s) for a patient with active coverages
          from two different payers and that all resulting hook requests have been sent.

          #{service_discovery_endpoints_section}
          #### Authentication and Identification

          #{session_identification_message}

          #### Responses

          Inferno will return a mocked coverage-information response.
        MESSAGE
      end
    end
  end
end
