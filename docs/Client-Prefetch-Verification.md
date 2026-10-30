The 2.0.1 version of CRD does not require prefetch and the v2.0.1
client suite handles prefetch checks differently than v2.2.1.
This page describes how the v2.2.1 client suite checks prefetch
requirements for CRD clients.

## Background

[Prefetch](https://cds-hooks.hl7.org/2026Jan/en/#prefetch-template) is a
mechanism by which CDS Hooks services can request clients to
provide additional information with the hook request. The 2.2.1 version
of the CRD IG [requires client support for prefetch](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#ci-c-found-24).
Payers can request
any information linked to the hook request's context details, though
they should [only request information that is always needed via prefetch](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#ci-c-found-27).
Clients are only required to be able to provide
[a "standard" set of information or a subset of it](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#ci-c-found-25)
via prefetch. When the service requests data outside of that set to be included within
the prefetched data set, clients are not obligated to provide it.

## Inferno's Verification

Several tests within Inferno's analysis of the hook requests sent by
the CRD client involve prefetch verification. This includes:
- On each hook invocation:
  - "Hook requests include the requested prefetch data": these tests verify
    that each hook request has the correct set of prefetch data based on
    calculations done by Inferno using Inferno's published prefetch
    templates and the FHIR resources in the request. For these tests, all
    requested data must be available and present within the hook request.
    To determine what should be present, Inferno calculates the expected
    prefetch set using the hook request and the [prefetch definitions](#inferno-requested-prefetches)
    for the invoked service, [resolving references](#reference-resolution-within-hook-requests)
    and executing FHIRPath.
  - "Prefetched coverages are issued by the payer associated with the invoked
    service": Coverages are issued by payers and each payer is associated
    with a CDS Hooks endpoint. Likewise in Inferno, testers must assign each
    Inferno simulated CRD server the Organization `id` representing the payer
    associated with the endpoint within the CRD client. Inferno checks
    that the Organization `id` indicated in
    the Coverage matches the one assigned to the invoked server.
- Across all hook invocations:
  - "CRD client correctly interprets collections when substituting FHIRPath results
    in prefetch templates": CRD clients must demonstrate, on at least one hook
    invocation, the ability to correctly [calculate FHIRPath results with multiple
    matches](https://cds-hooks.hl7.org/2026Jan/en/#prefetch-tokens-containing-simpler-fhirpath)
    within prefetch templates.
  - "CRD client can provide both the complete standard prefetch data set and
    a subset": CRD clients must demonstrate the ability to make hook requests
    against Inferno simulated CRD servers: the [complete prefetch services](#infernos-standard-services),
    and the [subset prefetch services](#infernos-subset-services). These
    requests must include at least one to each simulated server where the
    prefetched data set would not be the same if the same hook request were sent
    to the same hook service on the other server. See [Demonstrating Prefetch
    Calculation](#demonstrating-prefetch-calculation) below for details.

## Inferno Requested Prefetches

In order to verify CRD client conformance, Inferno's CRD server simulation hosts
two sets of CRD services with different sets of requested prefetch data:
one requesting the full "standard" set and the other requesting a strict subset of that.

### Inferno's Standard Services

Each of Inferno's standard set of services, available under
`custom/crd_client_v221/cds-services`, requests the complete CRD
[standard prefetch](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#standard-prefetch)
data set. That includes resources representing:
- The key people involved, including the
  patient along with ordering and performing providers.
- The key organizations and locations involved.
- The request for a service or product, such as an appointment or device, with product
  details.
- The relevant insurance coverage.

The discovery response returned by Inferno that requests this information can be found [here](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/v2.2.1/cds-services-v221.json).

### Inferno's Subset Services

In contrast, each of Inferno's subset services, available under `custom/crd_client_v221/prefetch-subset/cds-services`,
requests a subset of the full standard set. Compared to the "standard" prefetch data set,
the subset drops the following information from the prefetch, by hook:
- `appointment-book`: no Organizations, no people or Locations linked from the Appointment,
  no ordering providers from linked requests, and no participants linked
  only from the Encounter.
- `encounter-start` and `encounter-discharge`: no Organizations or Locations linked
  from the Encounter.
- `order-*`: no ordering providers, no Organizations, and no participants linked
  only from the Encounter.

Additionally, it uses non-standard prefetch keys. The discovery response returned
that requests this information can be found [here](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/v2.2.1/cds-services-prefetch-subset-v221.json).

### Demonstrating Prefetch Calculation

The primary purpose of having two service endpoints is to enable Inferno to confirm that
the CRD client is calculating the prefetch data it provides based on what is requested
in the service discovery response. The calculated set of prefetch data depends on the
requested prefetch templates in the service discovery response and the resources provided
within the hook request. Depending on the populated reference elements, the calculated
prefetch may be the same regardless of which Inferno service the request is sent to.
Inferno needs to see requests from the CRD client sent to each version of a hook service
where the set of prefetch data would be different if the same request had been
sent to the other service.

Testers can do this by making sure that a FHIR element not included in the subset service's
prefetch set is populated with a reference to a resource that is not referenced anywhere else.
The reference elements that meet this criteria are:
- On an `appointment-book` hook request, an Appointment with a `participant` entry that
  references a Practitioner or PractitionerRole resource in its `actor` element.
- On an `encounter-start` or `encounter-discharge` hook request, an Encounter with a
  referenced Location via the `location` element or referenced Organization via the
  `serviceProvider` element.
- On an `order-select`, `order-sign`, or `order-dispatch` hook request, one of the following order resources:
  - A CommunicationRequest, DeviceRequest, MedicationRequest, or ServiceRequest that references a Practitioner
    or PractitionerRole resource in its `requester` element, or
  - A NutritionOrder that references a Practitioner or PractitionerRole resource in its `orderer` element
  - A VisionPrescription that references a Practitioner or PractitionerRole resource in its `prescriber` element.

## Reference Resolution Within Hook Requests

The `context` of a CRD hook request contains references that the receiving
server needs to resolve in order to provide a response. Some of the
resources those references point to will be requested and provided within
the `prefetch` object of the request. Servers need a reliable way to determine
the absolute URL for each referenced resource and determine whether it is
already present within the hook request.

Many, but not all, of the resources within a hook request are found inside
FHIR Bundles, which have [well-defined rules](https://hl7.org/fhir/R4/bundle.html#references)
for determining both the absolute URL for a resource within it and how to
determine the absolute URL for a relative reference. References and resources
in the hook request that are not within a Bundle use the required
`fhirServer` property as the base FHIR server. The following sections describe
the specific rules by which Inferno determines the absolute URL for each
resource within a hook request and the absolute URL that every reference
refers to.

### Resource Identity

- Bundled resources: All Bundles embedded within hook requests will have a
  `type` of "collection" or "searchset", meaning that the `fullUrl` element
  is required on all entries. Inferno considers the `fullUrl` to be the
  absolute URL for resources found within a Bundle. If a Bundle entry does
  not have a `fullUrl`, Inferno will not resolve any references as pointing
  to that resource.
- Unbundled resources: Other resources, including direct `context` and
  `prefetch` non-Bundle resource values, are required to have an `id`.
  To form the absolute URL for such a resource, append the relative
  reference formed by the resource's `resourceType` and `id` to the
  value of the `fhirServer` property in the containing hook request.

### Finding Referenced Resources

To resolve a reference, Inferno first determines the absolute URL
that the reference points to. If the reference is not already
absolute, Inferno performs the conversion differently depending on
where the reference was found:
- Relative references that appear in bundled resources: Inferno uses the
  [Bundle reference resolution rules](https://hl7.org/fhir/R4/bundle.html#references)
  which create a [FHIR RESTful URL](https://hl7.org/fhir/R4/references.html#regex)
  using the relative reference and the base FHIR server extracted from the
  enclosing entry's `fullUrl`, if possible. Relative references within
  Bundle entries without a `fullUrl` or with a value that is not a
  [FHIR RESTful URL](https://hl7.org/fhir/R4/references.html#regex) will
  never resolve.
- Relative references that appear in unbundled resources: Inferno uses
  the `fhirServer` property in the containing hook request as the base
  FHIR server and constructs a [FHIR RESTful URL](https://hl7.org/fhir/R4/references.html#regex) with it and the relative reference.

Once Inferno has an absolute reference, it looks to see if there is a
resource in the hook request that has that URL as its identity using the
rules [described above](#resource-identity).

### FHIRPath `resolve()`

When executing the `resolve()` function, Inferno uses these same rules
to identify the absolute URL for the target resource and match it back
to a provided resource. When executing FHIRPath, only the identified
resources within the hook request are considered; Inferno will not
use fetched resources to supplement that set. Furthermore, if the
`resolve()` function fails, Inferno will never continue execution
even if it appears that the reference itself could supply the rest
of the information (e.g., `resolve().ofType(Patient).id` on the
reference `Patient/123`).

### Example

In the stripped-down hook request example, with malformed comments, below, there is a mix
of resources from and references to resources on `inferno.healthit.gov` and
`inferno-qa.healthit.gov`. Each relative reference has a comment following it
indicating the absolute URL it resolves to and the Patient resource that is
outside of a Bundle has its identity indicated in a comment as well.

The only reference that doesn't resolve to a resource within the hook request is
the "Practitioner/user" reference in the `context.userId` field. Because the
reference is found outside of a bundled resource, the `fhirServer` is used
as the base FHIR server. So Inferno looks for a resource in the hook request
with identity "https://inferno.healthit.gov/fhir/Practitioner/user". There is
a Practitioner resource with `id` "user", but it has identity
"https://inferno-qa.healthit.gov/fhir/Practitioner/user", indicating it lives
on the other server.

```
{
  "hook": "order-sign",
  "fhirServer": "https://inferno.healthit.gov/fhir",
  "context": {
    "userId": "Practitioner/user", // resolves to https://inferno.healthit.gov/fhir/Practitioner/user (not present)
    "patientId": "patient", // resolves to https://inferno.healthit.gov/fhir/Patient/patient
    "draftOrders": {
      "resourceType": "Bundle",
      "type": "collection",
      "entry": [
        {
          "fullUrl": "https://inferno.healthit.gov/fhir/DeviceRequest/devicerequest-different-orderer-vs-performer",
          "resource": {
            "resourceType": "DeviceRequest",
            "id": "devicerequest-different-orderer-vs-performer",
            "subject": {
              "reference": "Patient/patient" // resolves to https://inferno.healthit.gov/fhir/Patient/patient
            },
            "requester": {
              "reference": "Practitioner/orderer" // resolves to https://inferno.healthit.gov/fhir/Practitioner/orderer
            },
            "performer": {
              "reference": "https://inferno-qa.healthit.gov/fhir/PractitionerRole/role-performer"
            }
          }
        }
      ]
    }
  },
  "prefetch": {
    "patient": { // identity: https://inferno.healthit.gov/fhir/Patient/patient
      "resourceType": "Patient",
      "id": "patient"
    },
    "practitionerRoles": {
      "resourceType": "Bundle",
      "entry": [
        {
          "fullUrl": "https://inferno-qa.healthit.gov/fhir/PractitionerRole/role-performer",
          "resource": {
            "resourceType": "PractitionerRole",
            "id": "role-performer",
            "practitioner": {
              "reference": "Practitioner/performer" // resolves to https://inferno-qa.healthit.gov/fhir/Practitioner/performer
            }
          }
        }
      ]
    },
    "practitioners": {
      "resourceType": "Bundle",
      "entry": [
        {
          "fullUrl": "https://inferno.healthit.gov/fhir/Practitioner/orderer",
          "resource": {
            "resourceType": "Practitioner",
            "id": "orderer"
          }
        },
        {
          "fullUrl": "https://inferno-qa.healthit.gov/fhir/Practitioner/performer",
          "resource": {
            "resourceType": "Practitioner",
            "id": "performer"
          }
        },
        {
          "fullUrl": "https://inferno-qa.healthit.gov/fhir/Practitioner/user",
          "resource": {
            "resourceType": "Practitioner",
            "id": "user"
          }
        }
      ]
    }
  }
}
```
