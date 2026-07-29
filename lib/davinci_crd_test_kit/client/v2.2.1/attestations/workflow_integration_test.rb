module DaVinciCRDTestKit
  module V221
    class WorkflowIntegrationAttestationTest < Inferno::Test
      id :crd_v221_workflow_integration_attestation
      title 'Health IT module integrates hook invocations transparently into user workflows'
      description %(
        The Health IT module integrates CRD hook invocations into the regular user workflow:

        - Hook invocation occurs transparently as part of the user workflow.
        - Users are not required to transcribe order, appointment, or other data into a separate interface that
          is distinct from the regular provider workflow, unless they are performing a "what if" situation.
        - The CDS Hooks system action functionality is supported so that annotations are automatically stored on
          the relevant request, appointment, or other record without any user intervention.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@hook-7', 'hl7.fhir.us.davinci-crd_2.2.1@hook-8',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-48'

      input :workflow_integration_attestation,
            title: 'Health IT module integrates hook invocations transparently into user workflows',
            description: %(
              I attest that the Health IT module integrates CRD hook invocations into the regular user workflow:

              - Hook invocation occurs transparently as part of the user workflow.
                ([hook-7](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#ci-c-hook-7))
              - Users are not required to transcribe order, appointment, or other data into a separate interface
                that is distinct from the regular provider workflow, unless they are performing a "what if"
                situation.
                ([hook-8](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#ci-c-hook-8))
              - The CDS Hooks system action functionality is supported so that annotations are automatically
                stored on the relevant request, appointment, or other record without any user intervention.
                ([resp-48](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#ci-c-resp-48))
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
        assert workflow_integration_attestation == 'true',
               'Health IT module does not integrate hook invocations transparently into user workflows.'

        pass workflow_integration_attestation_note if workflow_integration_attestation_note.present?
      end
    end
  end
end
