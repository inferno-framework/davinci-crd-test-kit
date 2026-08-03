require_relative 'attestation_instructions'

module DaVinciCRDTestKit
  module V221
    class WorkflowIntegrationAttestationTest < Inferno::Test
      id :crd_v221_workflow_integration_attestation
      ATTESTATION_TITLE = 'Health IT module integrates hook invocations transparently into user workflows'.freeze
      title ATTESTATION_TITLE
      description %(
        During this test, the tester will confirm that the Health IT module integrates CRD hook invocations
        transparently into the regular user workflow.
        To see the specifics of the attested requirements, click the "View Specification Requirements" link for this
        test.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@hook-7', 'hl7.fhir.us.davinci-crd_2.2.1@hook-8',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-48'
      input_instructions ATTESTATION_INPUT_INSTRUCTIONS

      input :workflow_integration_attestation,
            title: ATTESTATION_TITLE,
            description: %(
              I attest that the Health IT module integrates CRD hook invocations transparently into the regular
              user workflow.
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }
      input :workflow_integration_attestation_note,
            title: 'Notes, if applicable:',
            type: 'textarea',
            optional: true

      run do
        assert workflow_integration_attestation == 'true'
      end
    end
  end
end
