module DaVinciCRDTestKit
  module V221
    class DataElementExpectationsAttestationTest < Inferno::Test
      id :crd_v221_data_element_expectations_attestation
      ATTESTATION_TITLE = 'Health IT module does not set additional expectations for data elements'.freeze
      title ATTESTATION_TITLE
      description %(
        The Health IT module does not place expectations on CRD servers beyond what the CRD specification
        requires:

        - It does not depend on or set expectations for CRD servers to communicate data elements that are not
          marked as mandatory or mustSupport in the CRD specification.
        - It does not treat the omission of a data element as an error where cardinality and other constraints
          in the profiles allow that element to be omitted.
        - It uses standard CRD data elements, meaning elements found within CRD-defined or inherited profiles
          and marked as mandatory or mustSupport, to communicate needed data where those elements are intended
          to convey such information.
        - It ignores unexpected elements when processing instances.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-10', 'hl7.fhir.us.davinci-crd_2.2.1@conf-12',
                            'hl7.fhir.us.davinci-crd_2.2.1@conf-13', 'hl7.fhir.us.davinci-crd_2.2.1@found-33'

      input :data_element_expectations_attestation,
            title: ATTESTATION_TITLE,
            description: %(
              I attest that the Health IT module does not place expectations on CRD servers beyond what the CRD
              specification requires:

              - It does not depend on or set expectations for CRD servers to communicate data elements that are
                not marked as mandatory or mustSupport in the CRD specification.
                ([conf-10](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-10))
              - It does not treat the omission of a data element as an error where cardinality and other
                constraints in the profiles allow that element to be omitted.
                ([conf-12](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-12))
              - It uses standard CRD data elements, meaning elements found within CRD-defined or inherited
                profiles and marked as mandatory or mustSupport, to communicate needed data where those elements
                are intended to convey such information.
                ([conf-13](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-13))
              - It ignores unexpected elements when processing instances.
                ([found-33](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#ci-c-found-33))
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }
      input :data_element_expectations_attestation_note,
            title: 'Notes, if applicable:',
            type: 'textarea',
            optional: true

      run do
        assert data_element_expectations_attestation == 'true',
               'Health IT module sets additional expectations for data elements beyond those required by CRD.'

        pass data_element_expectations_attestation_note if data_element_expectations_attestation_note.present?
      end
    end
  end
end
