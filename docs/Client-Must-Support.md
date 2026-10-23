# Client Must Support Tests

The v2.0.1 client suite does not currently test element-level must support
requirements, so this page is not relevant to those tests.

## Background

The must support flag is one mechanism used within FHIR to denote elements that
may not be required on all instances of a profile but are necessary to represent
the full scope of situations that the profile is designed to handle. Each FHIR IG
defines the precise meaning of must support within the profiles that it defines
and sets the requirements that the must support flag places on the different actors
defined by the IG.

Inferno generally validates must support definitions by analyzing a set of
resources gathered over one or more tests and checking that each must support
element defined in the relevant profile(s) has been observed populated at
least once.

## CRD Must Support Definitions for Clients

The 2.2.1 version of the CRD IG defines [must support requirements](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#mustsupport)
for clients as:
- **Data Source**: "If the CRD client maintains a mustSupport data element and
  surfaces it to users, then it **SHALL** be exposed in their FHIR interface when the data exists and privacy constraints permit." ([§conf-3](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-3))
  CRD clients act as data sources when they send data in the hook request, so Inferno
  will check requests made by the CRD client to confirm that relevant must support
  elements are all demonstrated.
- **Data Consumer**: "CRD clients **SHALL** make the mustSupport data available to the
  appropriate user (clinical or administrative) or leverage the data within their
  workflow as necessary to follow the intention of the provided decision support." ([§conf-6](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-6))
  CRD clients act as data consumers when they receive data in the hook response,
  so Inferno will check responses that it sent back to the CRD client to confirm that
  all relevant must support elements are demonstrated within them.
  
## Inferno Checks

### Requests

Inferno considers all must support elements defined on profiles explicitly referenced by
the [CRD hook profiles](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html)
as well as any CRD-defined profiles that those profiles reference. This includes
the following profiles:

- [CRD Appointment with Order](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-appointment-with-order.html)
  and [CRD Appointment without Order](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-appointment-no-order.html)
- [CRD Communication Request](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-communicationrequest.html)
- [CRD Coverage](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-coverage.html)
- [CRD Device](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-device.html)
- [CRD Device Request](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-devicerequest.html)
- [CRD Encounter](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-encounter.html)
- [CRD Location](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-location.html)
- [CRD Medication](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-medication.html)
- [CRD Medication Request](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-medicationrequest.html)
- [CRD Nutrition Order](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-nutritionorder.html)
- [CRD Organization](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-organization.html)
- [CRD Patient](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-patient.html)
- [CRD Practitioner](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-practitioner.html)
- [HRex PractitionerRole Profile](https://hl7.org/fhir/us/davinci-hrex/1.2.0/StructureDefinition-hrex-practitionerrole.html)
- [CRD Service Request](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-servicerequest.html)
- [CRD Vision Prescription](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-visionprescription.html)

For each of these profiles, Inferno performs two checks as described below.

#### Must Support Element Presence

Inferno looks across all resources provided within the hook request bodies (`context`
or `prefetch`) and confirms that it sees examples of each element flagged as must support.
Per the [CRD must support requirement](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-3)
on CRD clients when acting as data sources, a CRD client needs to support an element
only when it "maintains a mustSupport data element and surfaces it to users". Thus
Inferno allows testers to indicate that the CRD client does not support a must
support element through an attestation (see the [Attestation](#attestation) section
below for details).

#### Must Support References

To verify support for must support elements of the [Reference](https://hl7.org/fhir/R4/references.html)
type, Inferno must also be able to resolve observed references and follow them to actual
resources that conform to certain profiles. If Inferno cannot find all the examples it
needs to see for a referencing resource type, the test will skip.

When resolving references, Inferno first looks for the referenced resource
within the `context` or `prefetch` fields of the hook request and falls back to obtaining
the resource via a FHIR read during the hook invocation (see the [Prefetch and Additional Data Retrieval](Client-Details#prefetch-and-additional-data-retrieval)
section for details).

Using the resolved references, Inferno then confirms support for one or more
target profiles:
- When there is a single target profile allowed, Inferno verifies that it
  can find a resolved reference that conforms to that profile.
- When there are multiple target profiles and at least one has a must support flag,
  Inferno verifies that for each profile with the must support flag, it can find a
  resolved reference that conforms to that profile.
- Otherwise, Inferno verifies that it can find a resolved reference that conforms
  to at least one of the listed profiles.

There are two exclusions that Inferno makes when performing these checks. In both cases
the check is considered to have passed:
- When checking an element, if the target element is never populated, Inferno will
  consider the requirement to be met vacuously. Because the Reference element is must
  support, the [Must Support Element Presence](#must-support-element-presence)
  test will confirm whether support for this element needs to be demonstrated. If it
  does, then future runs of the reference test will find a populated example to check.
  If it does not, then pass is the correct result.
- When checking a specific profile, Inferno will not look for a resolved reference
  that conforms to the profile when the tester has attested via the test inputs
  that the profile's resource type is not supported by the CRD client (see the
  [Resource types](#resource-types) section below).

Note that not all references must resolve and conform to a required profile: Inferno must only
find one for each reference element and target profile. For this reason, detailed
conformance validation errors are not returned. While this avoids reporting errors for
references that do not matter to the result, it also makes it harder to determine what
caused the tests to not pass. The following information is available to help testers determine
what Inferno looked at and why it did not find all the examples it needed:
- The result message will name each element and target profile that was not
  demonstrated.
- The Requests tab for the test will include all the hook invocations that contain
  instances of the referencing resource type as well as the FHIR read interactions
  that Inferno made to obtain referenced resources that did not appear in the
  hook request body.

Additionally, the following is a list of reasons that Inferno can consider a populated
Reference element to not represent an example of a reference that resolves to a certain profile:
- It is a logical reference, carrying only an `identifier` or `display` without a `reference`.
- Its `reference` is neither a contained reference (`#id`), a relative `Type/id` reference, nor an absolute URL.
- It is a versioned reference (`Type/id/_history/vid`, relative or absolute), which
  Inferno does not currently resolve.
- It points to a contained resource whose id does not match any resource in `contained`.
- The resource it points to was neither carried in the hook request (in `context`
  or `prefetch`) nor successfully read by Inferno while processing that hook request.
  Check the Requests tab of the test for the FHIR reads considered and see the
  [Prefetch and Additional Data Retrieval](Client-Details#prefetch-and-additional-data-retrieval)
  section for details on how Inferno reads these resources.
- The resource it resolved to is not the resource type the target profile constrains
  (or, when any one of several target profiles will do, none of their types).
- The resource it resolved to does not conform to the target profile (or to any of
  the options). You can validate the resource against the profile manually using services
  such as [validator.fhir.org](https://validator.fhir.org/) to see why.

### Responses

Currently, Inferno only checks that CRD clients can receive the full scope of must support
elements for [coverage information responses](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type),
which is the only response type CRD clients are required to support.
The relevant must support elements are the must support sub-extensions within the
[coverage-information extension](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-ext-coverage-information.html).
All other information within the coverage information system action represents
echoed information.

Note that the [coverage-information extensions](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-ext-coverage-information.html)
provided as a part of Inferno's mocked responses do not include all must support
elements, so testers will need to provide responses for Inferno to use that include
examples of all must support elements to pass these tests.

Checks for must support information on other response types may be added to these tests
in the future.

## Evaluated Resources

When looking for must support elements Inferno will consider resources in all
requests and responses exchanged by Inferno and the CRD client during sub-groups
of the "Hooks" group and the "Additional Hook Invocations" group. The must support element tests consider resources within the
`context` and `prefetch` fields of hook requests. The must support reference tests
additionally consider resources obtained by FHIR read interactions that Inferno
performed while processing those hook requests. Resources exchanged during sub-groups of the "Scenarios" group
are not included in the analysis as those tests are more lax in their verification
of request content and response handling.

Note that Inferno will only consider requests and responses exchanged during the most
recent execution of each group. When any group is re-run, including the "Additional Hook
Invocations" group, the requests made during the
previous run of that group will no longer be considered.

## Attestation

To pass the CRD client must support tests without demonstrating all CRD-defined
must support elements across all of the CRD profiles, testers are able to attest
that the CRD client does not maintain or surface the data represented by the
profiles and elements not observed by Inferno. Testers do this in two
ways, one for resource types and the other for elements as described below.

### Resource Types

When running the "Must Support" group, testers are asked to indicate which resource
types the CRD client supports. When the tester indicates that a resource type
is not supported, the tests will fail if one is observed. They will also fail if
the CRD client invokes a hook whose requests always carry that resource type:
`appointment-book` for Appointment, and `encounter-start` or `encounter-discharge`
for Encounter. The tests will also
not check for demonstration of must support references pointing to resources
of that type. For must support references that can refer to the unsupported
resource type, testers will still need to attest that the CRD client does not
support the element if it will never be populated (see the [Elements](#elements)
section below).

Testers indicate support through one of two lists, for order types and
supporting types respectively.

#### Order types

For order types, testers will select all types of orders that the system supports
placing in the "Order types supported by the CRD client" input. Those selected will
be expected to appear within at least one invocation of a hook. Note that any
supported order type also must appear within an `order-sign` hook invocation due to
requirement [hook-3](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#ci-c-hook-3). The CRD order types include:

- [CRD Communication Request](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-communicationrequest.html)
- [CRD Device Request](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-devicerequest.html)
- [CRD Medication Request](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-medicationrequest.html)
- [CRD Nutrition Order](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-nutritionorder.html)
- [CRD Service Request](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-servicerequest.html)
- [CRD Vision Prescription](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-visionprescription.html)

#### Supporting types

Ancillary information such as specific medications or provider details are included
within supporting resource types. If the CRD client does not support representing
information using one of the supporting resource types, then testers can certify
this by unchecking one of the boxes in the "Supporting resource types populated
by the CRD client" input. Those that remain selected will be expected to appear
within at least one invocation of a hook. The supporting types include:

- [CRD Appointment with Order](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-appointment-with-order.html)
  and [CRD Appointment without Order](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-appointment-no-order.html)
- [CRD Device](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-device.html)
- [CRD Encounter](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-encounter.html)
- [CRD Location](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-location.html)
- [CRD Medication](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-medication.html)
- [CRD Organization](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-organization.html)
- [CRD Practitioner](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-practitioner.html)
- [HRex PractitionerRole Profile](https://hl7.org/fhir/us/davinci-hrex/1.2.0/StructureDefinition-hrex-practitionerrole.html)

#### Always required types

Two resource types are always required, and Inferno expects to observe at least one
instance of each:
- [CRD Coverage](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-coverage.html)
- [CRD Patient](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-patient.html)

### Elements

When Inferno finds instances of a resource type that it expects to observe
(see details in the [Resource types](#resource-types) section), it will look across
all instances to determine which must support elements were observed and which
were not. When some were not observed, Inferno will display a "User Action Required"
dialog listing all of the must support elements that were not observed. If the
CRD client does not make use of all of the listed elements as defined in CRD
requirement [§conf-3](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-3),
then the tester can confirm this by using the **true** link in the dialog to pass
the tests. Otherwise, the tester will use the **false** link in the dialog and the
test will fail. To review the elements Inferno did not observe after completing the
test, testers can look at the Messages tab for the corresponding test which will
include an "info" message for each element that Inferno did not observe regardless
of the tester's choice of attestation.

When a test fails or skips because supported elements were not demonstrated, testers may
re-run tests within the suite to demonstrate the additional elements and pass
the tests on a subsequent run. First, the tester can run or re-run
interaction tests and send requests that demonstrate the missing elements (and any
elements demonstrated only in the previous run of that group - see
[Evaluated Resources](#evaluated-resources)). Next, the tester can re-run
the "Must Support" group. Because re-running an interaction test can cause
demonstration of some elements to fall outside of the evaluated message scope,
testers will need to run the full set of must support tests again and re-do
all attestations for resource types on which the CRD client does not support
all must support elements.
