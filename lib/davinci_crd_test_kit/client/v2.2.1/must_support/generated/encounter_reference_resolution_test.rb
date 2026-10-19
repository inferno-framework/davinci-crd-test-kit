require_relative '../request_must_support_reference_resolution'

module DaVinciCRDTestKit
  module V221
    class EncounterReferenceResolutionTest < RequestMustSupportReferenceResolution
      id :crd_v221_encounter_must_support_reference_resolution
      title 'CRD Encounter must support references resolve'
      description <<~DESCRIPTION
        The CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-3)
        that when a client "maintains a mustSupport data element and surfaces it to users, then it
        SHALL be exposed in their FHIR interface when the data exists and privacy constraints permit."
        For a must support Reference element, this means that the referenced resource can be retrieved.
        Additionally, when some of the element's target profiles are themselves marked must support
        or the element has only one target profile, references to resources conforming to each of
        those profiles must be observed. Otherwise, a referenced resource must conform to any one of
        the element's target profiles.

        During this test, Inferno will check that for each must support Reference element listed
        below that was populated, at least one of its references resolved to a resource
        conforming to each target profile listed for the element, or to any one of them where the
        list says so. Target profiles for resource types the tester indicated the CRD client does not support are
        not checked.

        Inferno obtains the resources needed to perform these checks during the hook request by
        performing a FHIR read of any references in must support elements that aren't already
        present in the `context` or `prefetch` fields of the hook request. See the wiki's
        documentation on [simulated CRD server behavior](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#prefetch-and-additional-data-retrieval)
        for details on how Inferno gets these resources.

        If no instances of the resource type were observed, the test fails unless the tester
        indicated that the CRD client does not support the resource type.

        Inferno will consider the same hook requests as the must support
        element tests: those made during the latest run of each `Hooks` subgroup and the
        `Additional Hook Invocations for Cross Hook Support Demonstration` group.

        For additional details on this test, see the [Client Must Support Tests](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Must-Support)
        page and specifically the [Must Support References](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Must-Support#must-support-references)
        section in the CRD Test Kit wiki.


        ### CRD Encounter

        - `appointment`, any one of:
          - [CRD Appointment with Order](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-appointment-with-order.html)
          - [CRD Appointment without Order](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-appointment-no-order.html)
        - `diagnosis.condition`, any one of:
          - [US Core Condition Problems and Health Concerns Profile](https://hl7.org/fhir/us/core/STU7/StructureDefinition-us-core-condition-problems-health-concerns.html)
          - [US Core Condition Encounter Diagnosis Profile](https://hl7.org/fhir/us/core/STU7/StructureDefinition-us-core-condition-encounter-diagnosis.html)
          - [US Core Procedure Profile](https://hl7.org/fhir/us/core/STU7/StructureDefinition-us-core-procedure.html)
        - `location.location`
          - [CRD Location](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-location.html)
        - `participant.individual`
          - [US Core Practitioner Profile](https://hl7.org/fhir/us/core/STU7/StructureDefinition-us-core-practitioner.html)
        - `reasonReference`
          - [US Core Condition Problems and Health Concerns Profile](https://hl7.org/fhir/us/core/STU7/StructureDefinition-us-core-condition-problems-health-concerns.html)
          - [US Core Condition Encounter Diagnosis Profile](https://hl7.org/fhir/us/core/STU7/StructureDefinition-us-core-condition-encounter-diagnosis.html)
        - `serviceProvider`
          - [US Core Organization Profile](https://hl7.org/fhir/us/core/STU7/StructureDefinition-us-core-organization.html)
        - `subject`
          - [CRD Patient](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-patient.html)
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-3'

      config(
        options: {
          ig_version: 'v2.2.1',
          profiles: [
            { resource_type: 'Encounter', supporting_profile: true, profile_keys: ['encounter'] }
          ]
        }
      )
    end
  end
end
