module DaVinciCRDTestKit
  module V221
    class AuthorizedScopeAttestationTest < Inferno::Test
      id :crd_v221_authorized_scope_attestation
      title "Health IT module takes the user's authorized scope into account when providing data during " \
            'CDS Hook invocations'
      description %(
        The Health IT module limits the data it makes available to CDS Services to what the current user is
        authorized to access:

        - Prefetched data only includes resources that are within the user's authorized scope.
        - The data to which a CDS Service is given access is limited to the same restrictions and authorizations
          afforded the current user.
        - The access token provided to a CDS Service is scoped to the CDS Service being invoked and to the
          current user.
        - Access is denied to any requested resource that is outside the user's authorized scope.
      )
      attestation
      verifies_requirements 'cds-hooks_3.0.0-ballot@42', 'cds-hooks_3.0.0-ballot@63', 'cds-hooks_3.0.0-ballot@64',
                            'cds-hooks_3.0.0-ballot@173'

      input :authorized_scope_attestation,
            title: "Health IT module takes the user's authorized scope into account when providing data during " \
                   'CDS Hook invocations',
            description: %(
              I attest that the Health IT module limits the data it makes available to CDS Services to what the
              current user is authorized to access:

              - Prefetched data only includes resources that are within the user's authorized scope.
                ([CDS Hooks prefetch template](https://cds-hooks.hl7.org/2026Jan/en/index.html#prefetch-template))
              - The data to which a CDS Service is given access is limited to the same restrictions and
                authorizations afforded the current user, and the access token provided to a CDS Service is
                scoped to the CDS Service being invoked and to the current user.
                ([CDS Hooks FHIR resource access](https://cds-hooks.hl7.org/2026Jan/en/index.html#fhir-resource-access))
              - Access is denied to any requested resource that is outside the user's authorized scope.
                ([CDS Hooks trusting CDS services](https://cds-hooks.hl7.org/2026Jan/en/index.html#trusting-cds-services))
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }
      input :authorized_scope_attestation_note,
            title: 'Notes, if applicable:',
            type: 'textarea',
            optional: true

      run do
        assert authorized_scope_attestation == 'true',
               "Health IT module does not take the user's authorized scope into account when providing data " \
               'during CDS Hook invocations.'

        pass authorized_scope_attestation_note if authorized_scope_attestation_note.present?
      end
    end
  end
end
