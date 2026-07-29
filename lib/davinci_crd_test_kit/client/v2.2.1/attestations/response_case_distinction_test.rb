module DaVinciCRDTestKit
  module V221
    class ResponseCaseDistinctionAttestationTest < Inferno::Test
      id :crd_v221_response_case_distinction_attestation
      title 'Health IT module distinguishes different response cases to users'
      description %(
        The Health IT module distinguishes between the different CRD response cases when presenting results
        to users:

        - If it suppresses "default presumption" coverage information messages, it mitigates the potential for
          those messages to be misinterpreted in the event that CRD is unavailable.
        - Discrete information propagated into the order extension is available to the user for viewing. This
          may be handled with icons, flyovers, or other mechanisms instead of traditional CDS Hooks card
          rendering.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@impl-1', 'hl7.fhir.us.davinci-crd_2.2.1@resp-49'

      input :response_case_distinction_attestation,
            title: 'Health IT module distinguishes different response cases to users',
            description: %(
              I attest that the Health IT module distinguishes between the different CRD response cases when
              presenting results to users:

              - If it suppresses "default presumption" coverage information messages, it mitigates the potential
                for those messages to be misinterpreted in the event that CRD is unavailable.
                ([impl-1](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/implementation.html#ci-c-impl-1))
              - Discrete information propagated into the order extension is available to the user for viewing.
                This may be handled with icons, flyovers, or other mechanisms instead of traditional CDS Hooks
                card rendering.
                ([resp-49](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#ci-c-resp-49))
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }
      input :response_case_distinction_attestation_note,
            title: 'Notes, if applicable:',
            type: 'textarea',
            optional: true

      run do
        assert response_case_distinction_attestation == 'true',
               'Health IT module does not distinguish the different CRD response cases to users.'

        pass response_case_distinction_attestation_note if response_case_distinction_attestation_note.present?
      end
    end
  end
end
