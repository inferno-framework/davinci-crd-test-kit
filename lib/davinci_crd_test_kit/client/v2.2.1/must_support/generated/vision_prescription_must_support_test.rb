require_relative '../request_must_support_with_attestation_option'

module DaVinciCRDTestKit
  module V221
    class VisionPrescriptionMustSupportTest < RequestMustSupportWithAttestationOption
      id :crd_v221_vision_prescription_must_support
      title 'CRD Vision Prescription must support elements are observed'
      description <<~DESCRIPTION
        The CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-3)
        that when a client "maintains a mustSupport data element and surfaces it to users, then it
        SHALL be exposed in their FHIR interface when the data exists and privacy constraints permit."

        During this test, Inferno will check whether all must support elements defined in the
        profile(s) listed below are demonstrated within hook requests made during this session.
        This check may vacuously pass if the tester has attested that this resource type is not
        supported by the client system or if the relevant hooks are not invoked.

        If any must support elements are not demonstrated, the tester will have the option to attest
        that these elements are not supported by the client system or surfaced to its users. Testers
        must setup scenarios in which the "data exists and privacy constraints permit" Inferno to view
        the must support information.

        Inferno will consider resources present within the `context` and `prefetch` elements of all hook
        requests made during the latest run of each `Hooks` subgroup and the `Additional Hook
        Invocations for Cross Hook Support Demonstration` group, but not any made within the `Scenarios`
        subgroups. If any of the considered groups are re-run, then requests made during prior runs will
        no longer be considered and must support elements demonstrated only during that prior run must
        be re-demonstrated on the new run or a subsequent one.


        ### [CRD Vision Prescription](http://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-visionprescription.html)

        - `contained`
        - `created`
        - `dateWritten`
        - `encounter`
        - `extension:Coverage-Information`
        - `extension:EncounterCategory`
        - `extension:ServiceCategory`
        - `identifier`
        - `lensSpecification`
        - `lensSpecification.add`
        - `lensSpecification.axis`
        - `lensSpecification.backCurve`
        - `lensSpecification.cylinder`
        - `lensSpecification.diameter`
        - `lensSpecification.duration`
        - `lensSpecification.extension:BillingOptions`
        - `lensSpecification.eye`
        - `lensSpecification.power`
        - `lensSpecification.prism`
        - `lensSpecification.prism.amount`
        - `lensSpecification.prism.base`
        - `lensSpecification.product`
        - `lensSpecification.sphere`
        - `patient`
        - `prescriber`
        - `status`
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-3',
                            'hl7.fhir.us.davinci-crd_2.2.1@hook-3'

      config(
        options: {
          ig_version: 'v2.2.1',
          profiles: [
            { resource_type: 'VisionPrescription', profile_keys: ['vision_prescription'] }
          ]
        }
      )
    end
  end
end
