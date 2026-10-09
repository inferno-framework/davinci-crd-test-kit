require_relative '../request_must_support_reference_resolution'

module DaVinciCRDTestKit
  module V221
    class CoverageReferenceResolutionTest < RequestMustSupportReferenceResolution
      id :crd_v221_coverage_must_support_reference_resolution
      title 'CRD Coverage must support references resolve'
      description <<~DESCRIPTION
        The CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-3)
        that when a client "maintains a mustSupport data element and surfaces it to users, then it
        SHALL be exposed in their FHIR interface when the data exists and privacy constraints permit."
        For a must support Reference element, this means that the referenced resource can be
        retrieved and conforms to the profiles the element targets.

        During this test, Inferno will check that for each must support Reference element listed
        below that was populated with a literal reference, at least one of those references
        resolved to a resource conforming to each target profile listed for the element. Target
        profiles for resource types the tester indicated the CRD client does not support are not
        checked.

        A CRD server can only retrieve data from the CRD client's FHIR server while it is processing
        a hook request, so Inferno reads the referenced resources as each hook request arrives.
        Using the `fhirServer` and `fhirAuthorization` provided in the request, Inferno reads each
        resource referenced from a must support Reference element of a resource in the `context`
        or `prefetch`, and the resources referenced in turn from those it reads. References to
        resources on other servers are read from those servers without the access token, which
        is only for the `fhirServer`.

        Resources and references are matched by absolute URL. A resource in a Bundle is
        identified by the entry's `fullUrl`, and any other resource is assumed to be on the
        `fhirServer`. A relative reference is resolved against the server of the resource holding
        it. A reference resolves when it points to a contained resource, to a resource carried in
        the same hook request, or to a resource Inferno read while processing it.

        The test will skip if a must support Reference element was populated but none of its
        references resolved. Inferno will consider the same hook requests as the must support
        element tests: those made during the latest run of each `Hooks` subgroup and the
        `Additional Hook Invocations for Cross Hook Support Demonstration` group.


        ### CRD Coverage

        - `beneficiary`: `http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-patient`
        - `payor`: `http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-organization`
        - `policyHolder`
        - `subscriber`: `http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-patient`
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-3'

      config(
        options: {
          ig_version: 'v2.2.1',
          profiles: [
            { resource_type: 'Coverage', supporting_profile: true, profile_keys: ['coverage'] }
          ]
        }
      )
    end
  end
end
