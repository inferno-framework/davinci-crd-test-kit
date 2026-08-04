require_relative 'attestation_instructions'

module DaVinciCRDTestKit
  module V221
    class AuthorizedScopeAttestationTest < Inferno::Test
      id :crd_v221_authorized_scope_attestation
      ATTESTATION_TITLE = "Health IT module takes the user's authorized scope into account when providing data " \
                          'during CDS Hook invocations'.freeze
      title ATTESTATION_TITLE
      description %(
        During this test, the tester will confirm that the Health IT module limits the data it makes available to CDS
        Services to what the current user is authorized to access.
        To see the specifics of the attested requirements, click the "View Specification Requirements" link for this
        test.
      )
      attestation
      verifies_requirements 'cds-hooks_3.0.0-ballot@42', 'cds-hooks_3.0.0-ballot@63', 'cds-hooks_3.0.0-ballot@64',
                            'cds-hooks_3.0.0-ballot@173'
      input_instructions ATTESTATION_INPUT_INSTRUCTIONS

      input :authorized_scope_attestation,
            title: ATTESTATION_TITLE,
            description: %(
              I attest that the Health IT module limits the data it makes available to CDS Services to what the
              current user is authorized to access.
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
        assert authorized_scope_attestation == 'true'
      end
    end
  end
end
