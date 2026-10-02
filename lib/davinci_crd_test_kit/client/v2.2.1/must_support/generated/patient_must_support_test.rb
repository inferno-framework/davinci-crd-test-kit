require_relative '../request_must_support_with_attestation_option'

module DaVinciCRDTestKit
  module V221
    class PatientMustSupportTest < RequestMustSupportWithAttestationOption
      id :crd_v221_patient_must_support
      title 'CRD Patient must support elements are observed'
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


        ### CRD Patient

        - `address`
        - `address.city`
        - `address.country`
        - `address.line`
        - `address.postalCode`
        - `address.state`
        - `birthDate`
        - `communication.language`
        - `gender`
        - `identifier`
        - `identifier.system`
        - `identifier.value`
        - `name`
        - `name.family`
        - `name.given`
        - `telecom.system`
        - `telecom.use`
        - `telecom.value`
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-3'

      config(
        options: {
          ig_version: 'v2.2.1',
          profiles: [
            { resource_type: 'Patient', supporting_profile: true, profile_keys: ['patient'] }
          ]
        }
      )
    end
  end
end
