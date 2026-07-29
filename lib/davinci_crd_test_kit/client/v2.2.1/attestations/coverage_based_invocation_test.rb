module DaVinciCRDTestKit
  module V221
    class CoverageBasedInvocationAttestationTest < Inferno::Test
      id :crd_v221_coverage_based_invocation_attestation
      title 'Health IT module invokes hooks appropriately based on active coverage(s)'
      description %(
        The Health IT module uses the patient's coverage information to decide which payer services to invoke:

        - Hooks are only invoked on payer services where the patient record indicates active coverage with the
          payer associated with the service, and where there is no recorded indication that the patient intends
          to bypass insurance coverage, such as a service or product flagged as "patient-pay".
        - Where a patient has multiple active coverages that could be relevant to the current order,
          appointment, or other activity, the coverage most likely to be primary is selected and coverage
          information is solicited for that one payer only.
        - If services are invoked on other payers, the response types that return coverage information are
          disabled for those "likely secondary" payers.
        - Where multiple active coverages are deemed appropriate to call, all CRD server calls are invoked in
          parallel and their results are displayed simultaneously to ensure a timely response to user action.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@dev-26', 'hl7.fhir.us.davinci-crd_2.2.1@dev-28',
                            'hl7.fhir.us.davinci-crd_2.2.1@dev-30', 'hl7.fhir.us.davinci-crd_2.2.1@dev-32'

      input :coverage_based_invocation_attestation,
            title: 'Health IT module invokes hooks appropriately based on active coverage(s)',
            description: %(
              I attest that the Health IT module uses the patient's coverage information to decide which payer
              services to invoke:

              - Hooks are only invoked on payer services where the patient record indicates active coverage with
                the payer associated with the service, and where there is no recorded indication that the
                patient intends to bypass insurance coverage, such as a service or product flagged as
                "patient-pay".
                ([dev-26](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/deviations.html#ci-c-dev-26))
              - Where a patient has multiple active coverages that could be relevant to the current order,
                appointment, or other activity, the coverage most likely to be primary is selected and coverage
                information is solicited for that one payer only.
                ([dev-28](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/deviations.html#ci-c-dev-28))
              - If services are invoked on other payers, the response types that return coverage information are
                disabled for those "likely secondary" payers.
                ([dev-30](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/deviations.html#ci-c-dev-30))
              - Where multiple active coverages are deemed appropriate to call, all CRD server calls are invoked
                in parallel and their results are displayed simultaneously to ensure a timely response to user
                action.
                ([dev-32](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/deviations.html#ci-c-dev-32))
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }
      input :coverage_based_invocation_attestation_note,
            title: 'Notes, if applicable:',
            type: 'textarea',
            optional: true

      run do
        assert coverage_based_invocation_attestation == 'true',
               'Health IT module does not invoke hooks appropriately based on the patient active coverages.'

        pass coverage_based_invocation_attestation_note if coverage_based_invocation_attestation_note.present?
      end
    end
  end
end
