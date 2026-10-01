require_relative '../request_must_support_with_attestation_option'

module DaVinciCRDTestKit
  module V221
    class PractitionerRoleMustSupportTest < RequestMustSupportWithAttestationOption
      id :crd_v221_practitioner_role_must_support
      title 'HRex PractitionerRole Profile must support elements are observed'
      description <<~DESCRIPTION
        CRD clients populate the FHIR resources they send within a hook request from the data
        they maintain. During this test, Inferno checks the resources found in the `context` and
        `prefetch` of every hook request received so far, and verifies that each must support
        element below was populated on at least one instance.

        Elements that were not observed do not fail this test on their own. Inferno will instead
        ask the tester to attest that the client system does not capture that data or does not
        surface it to its users. The same applies to a resource type that was not seen at all,
        which the tester may attest the system does not support.

        To demonstrate elements that earlier hook requests did not cover, use the
        "Additional Hook Invocations for Cross Hook Support Demonstration" group to send more
        requests, then re-run this group.


        ### HRex PractitionerRole Profile

        - `code`
        - `endpoint`
        - `location`
        - `organization`
        - `practitioner`
        - `specialty`
        - `telecom`
        - `telecom.system`
        - `telecom.value`
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-3'

      config(
        options: {
          ig_version: 'v2.2.1',
          profiles: [
            { resource_type: 'PractitionerRole', supporting_profile: true, profile_keys: ['practitioner_role'] }
          ]
        }
      )
    end
  end
end
