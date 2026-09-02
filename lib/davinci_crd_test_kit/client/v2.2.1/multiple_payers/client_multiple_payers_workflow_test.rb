require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    class ClientMultiplePayersWorkflowTest < Inferno::Test
      include ClientURLs

      id :crd_v221_client_multiple_payers_workflow
      title 'Client performs a workflow for a patient with multiple payer coverages'
      description %(
        During this test, the tester will perform a workflow that triggers hook invocation for a
        patient that has two active coverages associated with two different payers, each associated
        with one of Inferno's simulated CRD servers. The client is expected to solicit coverage
        information from only the payer associated with the coverage most likely to be primary and
        may also invoke the hook on the other payer with coverage information disabled. Inferno will
        return a fixed [mocked response](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
        containing only a coverage information system action, which is omitted for requests that
        disable coverage information through the `davinci-crd.configuration` extension, and testers
        cannot change the response that is returned. Inferno will wait until the tester acknowledges
        that all hook requests triggered by the workflow have been sent, and the next test will
        verify that the client solicited coverage information from only one payer.
      )

      input :cds_jwt_iss,
            title: 'CRD JWT Issuer',
            description: %(
              Value of the `iss` claim that must be present in the JWT used to authorize the client's hook
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

      def service_endpoint_details
        complete_note = payer_organization_note(complete_prefetch_service_organization_id)
        subset_note = payer_organization_note(subset_prefetch_service_organization_id)
        "- Complete Prefetch: `#{discovery_url}`#{complete_note}\n            " \
          "- Subset Prefetch: `#{prefetch_subset_discovery_url}`#{subset_note}"
      end

      run do
        identifier = cds_jwt_iss
        continuation_url = "#{resume_pass_url}?token=#{identifier}"
        output(continuation_url:)

        wait(
          identifier:,
          message: %(
            **Multiple Payers Workflow Test**:

            Perform a workflow that triggers hook invocation, such as one performed during
            previous tests, for a patient that has two active coverages associated with two
            different payers, each the payer associated with one of the two Inferno simulated
            CRD servers discoverable at the following endpoints:

            #{service_endpoint_details}

            For Inferno to recognize these requests and associate them with this session,
            the authentication JWT sent as a Bearer token in the Authorization header
            must have `#{cds_jwt_iss}` as the `iss` claim in the JWT payload.

            By [clicking here](#{continuation_url}) I attest that a user completed a workflow
            in the client system that triggered hook invocation for a patient with active
            coverages from two different payers and that all resulting hook requests have
            been sent.
          )
        )
      end
    end
  end
end
