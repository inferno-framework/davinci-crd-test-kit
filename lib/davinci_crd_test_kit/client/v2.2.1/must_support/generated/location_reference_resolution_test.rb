require_relative '../request_must_support_reference_resolution'

module DaVinciCRDTestKit
  module V221
    class LocationReferenceResolutionTest < RequestMustSupportReferenceResolution
      id :crd_v221_location_must_support_reference_resolution
      title 'CRD Location must support references resolve'
      description <<~DESCRIPTION
        The CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-3)
        that when a client "maintains a mustSupport data element and surfaces it to users, then it
        SHALL be exposed in their FHIR interface when the data exists and privacy constraints permit."
        For a must support Reference element, this means that the referenced resource can be retrieved.
        Additionally, when some of the element's target profiles are themselves marked must support
        or the element has only one target profile, references to resources conforming to each of
        those profiles must be observed.

        During this test, Inferno will check that for each must support Reference element listed
        below that was populated, at least one of its references resolved to a resource
        conforming to each target profile listed for the element. Target profiles for resource types
        the tester indicated the CRD client does not support are not checked.

        Inferno obtains the resources needed to perform these checks during the hook request by
        performing a FHIR read of any references in must support elements that aren't already
        present in the `context` or `prefetch` fields of the hook request. See the wiki's
        documentation on [simulated CRD server behavior](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#prefetch-and-additional-data-retrieval)
        for details on how Inferno gets these resources.

        Inferno will consider the same hook requests as the must support
        element tests: those made during the latest run of each `Hooks` subgroup and the
        `Additional Hook Invocations for Cross Hook Support Demonstration` group.

        For additional details on this test, see the [Client Must Support Tests](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Must-Support)
        page and specifically the [Must Support References](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Must-Support#must-support-references)
        section in the CRD Test Kit wiki.


        ### CRD Location

        - `managingOrganization`
          - [CRD Organization](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-organization.html)
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-3'

      config(
        options: {
          ig_version: 'v2.2.1',
          profiles: [
            { resource_type: 'Location', supporting_profile: true, profile_keys: ['location'] }
          ]
        }
      )
    end
  end
end
