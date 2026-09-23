require_relative 'attestations/attestation_instructions'
require_relative 'attestations/client_authorized_scope_attestation_test'
require_relative 'attestations/client_coverage_based_invocation_attestation_test'
require_relative 'attestations/client_data_element_expectations_attestation_test'
require_relative 'attestations/client_hook_invocation_logging_attestation_test'
require_relative 'attestations/client_must_support_use_attestation_test'
require_relative 'attestations/client_prefetch_key_omission_attestation_test'
require_relative 'attestations/client_resource_identifiers_attestation_test'
require_relative 'attestations/client_response_case_distinction_attestation_test'
require_relative 'attestations/client_security_and_privacy_attestation_test'
require_relative 'attestations/client_workflow_integration_attestation_test'

module DaVinciCRDTestKit
  module V221
    class CRDClientAttestationsGroup < Inferno::TestGroup
      id :crd_v221_client_attestations
      title 'Visual Inspection and Attestation'
      description %(
        Each test in this group asks the tester to confirm system conformance to one or more
        **SHALL** requirements from the [CRD v2.2.1 Implementation Guide](https://hl7.org/fhir/us/davinci-crd/2.2.1)
        or the [CDS Hooks specification](https://cds-hooks.hl7.org/2026Jan/en/).
        The tester attests that the client system under test meets the statement by selecting "Yes",
        and may record supporting details in the accompanying notes field. Selecting "No" fails the
        test. Notes provided are recorded in the test result.

        Testers are responsible for confirming that their system meets all requirements associated with a test
        before selecting "Yes" on the attestation input with the same name as the test. The text of the
        attested requirement(s) for each input can be reviewed by clicking the "View Specification Requirements" link
        in the "About" tab of the test with the same name.
      )
      input_instructions ATTESTATION_INPUT_INSTRUCTIONS

      test from: :crd_v221_security_and_privacy_attestation
      test from: :crd_v221_response_case_distinction_attestation
      test from: :crd_v221_data_element_expectations_attestation
      test from: :crd_v221_resource_identifiers_attestation
      test from: :crd_v221_workflow_integration_attestation
      test from: :crd_v221_coverage_based_invocation_attestation
      test from: :crd_v221_prefetch_key_omission_attestation
      test from: :crd_v221_hook_invocation_logging_attestation
      test from: :crd_v221_authorized_scope_attestation
      test from: :crd_v221_must_support_use_attestation
    end
  end
end
