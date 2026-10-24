require_relative '../request_must_support_with_attestation_option'

module DaVinciCRDTestKit
  module V221
    class DeviceRequestMustSupportTest < RequestMustSupportWithAttestationOption
      id :crd_v221_device_request_must_support
      title 'CRD Device Request must support elements are observed'
      description <<~DESCRIPTION
        The CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-3)
        that when a client "maintains a mustSupport data element and surfaces it to users, then it
        SHALL be exposed in their FHIR interface when the data exists and privacy constraints permit."

        During this test, Inferno will check whether all must support elements defined in the
        profile(s) listed below are demonstrated within hook requests made during this session.
        This check may vacuously pass if the tester has attested that this resource type is not
        supported by the CRD client.

        If any must support elements are not demonstrated, the tester will have the option to attest
        that these elements are not supported by the CRD client or surfaced to its users. Testers
        must setup scenarios in which the "data exists and privacy constraints permit" Inferno to view
        the must support information.

        Inferno will consider resources present within the `context` and `prefetch` elements of all hook
        requests made during the latest run of each `Hooks` subgroup and the `Additional Hook
        Invocations` group, but not any made within the `Scenarios`
        subgroups. If any of the considered groups are re-run, then requests made during prior runs will
        no longer be considered and must support elements demonstrated only during that prior run must
        be re-demonstrated on the new run or a subsequent one.

        For additional details on this test, see the [Client Must Support Tests](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Must-Support)
        page and specifically the [Requests](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Must-Support#requests)
        section in the CRD Test Kit wiki.


        ### [CRD Device Request](http://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-devicerequest.html)

        - `authoredOn`
        - `basedOn`
        - `code[x]`
        - `code[x]:codeCodeableConcept`
        - `code[x]:codeCodeableConcept.extension:BillingOptions`
        - `code[x]:codeReference`
        - `contained`
        - `extension:Coverage-Information`
        - `extension:EncounterCategory`
        - `extension:ServiceCategory`
        - `identifier`
        - `occurrence[x]`
        - `parameter`
        - `performer`
        - `reasonCode`
        - `reasonReference`
        - `requester`
        - `status`
        - `subject`
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-3',
                            'hl7.fhir.us.davinci-crd_2.2.1@hook-3',
                            'hl7.fhir.us.davinci-crd_2.2.1@billopt-1'

      config(
        options: {
          ig_version: 'v2.2.1',
          profiles: [
            { resource_type: 'DeviceRequest', profile_keys: ['device_request'] }
          ]
        }
      )
    end
  end
end
