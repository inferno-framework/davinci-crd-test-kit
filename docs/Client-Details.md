# Client Suite Implementation Details

The Da Vinci CRD Test Kit contains suites validating the conformance of client systems
to two versions of the HL7® FHIR® Da Vinci Coverage Requirements Discovery Implementation Guide:
- [v2.0.1](https://hl7.org/fhir/us/davinci-crd/STU2)
- [v2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1)

These tests are a **DRAFT** intended to allow CRD client implementers to perform
preliminary checks of their clients against CRD IG requirements and [provide
feedback](https://github.com/inferno-framework/davinci-crd-test-kit/issues)
on the tests. Future versions of these tests may validate other
requirements and may change the test validation logic.

## Technical Implementation

For these suites, Inferno [simulates a CRD payer server](#cds-services-simulation)
for the client system to interact with. The client will be expected to initiate
requests to the server, allow Inferno to access data using FHIR APIs, and
demonstrate its ability to react to the returned responses. Over the course of these
interactions, Inferno will seek to observe conformant handling of CRD requirements as
defined in the targeted CRD version.

The client suites each contain two top-level groups:
- In the "Hook Invocation" group, client systems will register Inferno's simulated
  CRD discovery endpoint(s) against payer(s) and demonstrate invocations of
  the CRD-specified hooks ([v2.0.1](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html),
  [v2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html)) that they support.
  Support for features required across all hooks but not necessarily on each one will
  also be checked as a part of this group.
- In the "FHIR API" group, client systems will demonstrate that they can act as
  a FHIR server, including general US Core read and search API requirements
  as well as the ability to support updates as a part of CRD responses such
  as the coverage-information response type ([v2.0.1](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information),
  [v2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type)).

All FHIR resources present in requests and responses, both FHIR and CDS Hooks, will be checked
for conformance to the CRD IG and CDS Hooks requirements individually and used in aggregate
to determine whether required features and functionality are present. HL7® FHIR® resources are
validated with the Java validator using `tx.fhir.org` as the terminology server. CDS Hooks request
and response objects may also be checked using the validator against defined logical models
in versions that support them (e.g., [v2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/artifacts.html#structures-logical-models)).

## CRD Server Simulation

### Simulated CRD Server in the CRD Client v2.0.1 Suite

The Da Vinci CRD Client v2.0.1 Test Suite provides basic CDS services for
[the six hooks contained in the implementation guide](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html).
The discovery endpoint is located at `custom/crd_client/cds-services` under the root Inferno deployment
address, e.g., `https://inferno.healthit.gov/suites/custom/crd_client/cds-services` for the publicly
hosted deployment of this test kit. The discovery response returned can be found [here](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/v2.0.1/cds-services-v201.json).

The rest of this section provides details on the implementation of these services and the expected
behavior when invoked by tested clients.

#### Data Fetching During Hook Invocations

##### CRD and CDS Hooks requirements around data availablity and access

The CRD IG requires that clients make data beyond the details provided in the hook request body available
to servers so that payers can use it as a part of coverage determination. The IG lists the [minimum that
payers need to make available](https://hl7.org/fhir/us/davinci-crd/STU2/foundation.html#additional-data-retrieval):

- Patient
- Relevant Coverage
- Authoring Practitioner
- Authoring Organization
- Requested performing Practitioner (if specified)
- Requested performing Organization (if specified)
- Requested Location (if specified)
- Associated Medication (if any)
- Associated Device (if any)

However, the IG also acknowledges that
- CRD servers may not always need all of this information in all circumstances.
- CRD clients may not have all of this information, e.g., the performing practitioner may not be known at order time.
- Specific CRD servers may not be authorized to access all of this data.

Two mechanisms for making the data available are specified:
- [Prefetch](https://hl7.org/fhir/us/davinci-crd/STU2/foundation.html#prefetch), where the CRD server indicates what
  data it will always need as a part of discovery and the client provides this information with the hook request.
- [FHIR Resource Access](https://hl7.org/fhir/us/davinci-crd/STU2/foundation.html#fhir-resource-access), where
  the CRD server uses an access token provided in the hook request to make FHIR queries to get additional data.

CRD clients must provide an access token for data access but are not required to support prefetch (though prefetch
may become required in later versions of the CRD spec).

##### Inferno simulated services behavior for data availability and access

Even though this information is not required to be available and accessible in all cases, these tests are designed
to allow CRD clients to demonstrate that they can make the information captured in their system
available to the CRD servers on which they invoke hooks. Therefore,
- Inferno [advertizes prefetch templates](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/routes/cds-services.json)
  requesting a subset of this data that clients can provide with the hook request if they support prefetch.
  Subsequent tests will check that the prefetched data is equivalent to what can be accessed via FHIR queries.
- When a client makes a hook invocation, Inferno will analyze the hook request and prefetched data and attempt to
  retrieve the rest of the available resources in the minimum data set. Subsequent tests will check that these
  requests all succeeded and fail if they did not. Testers will need to choose a hook invocation target and
  payer / user configuration that demonstrates this access.

##### Fetch interactions

Inferno performs individual reads for each resource identified. While this involves additional requests, support
for these read interactions is required by the CRD Client CapabilityStatement and the US Core Server CapabilityStatement
that it builds on. In practice clients may support and payers may use more efficient queries that
are not tested by Inferno.

The one exception is `Coverages`, which are obtained via the same search advertized in
[Inferno's prefetch templates](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/routes/cds-services.json).
  
##### Specific elements targeted

While the CRD STU2 IG does not provide precise definitions of the FHIR elements that constitute the minimum
data set, recent builds of the IG provide more explicit elements that represent the minimum data set as a part
of [minimal prefetch templates](https://build.fhir.org/ig/HL7/davinci-crd/en/Binary-CRDServices.html).
The elements indicated in those prefetch templates informed the set of elements that Inferno looks in to determine
what references to fetch.

Any literal reference, relative or absolute, Inferno will attempt to read using the provided access token.
Non-literal references will be ignored.

#### CDS Hooks Responses

THe CRD client test suite contains [basic logic to generate CDS Hooks responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
that meet each of the [CRD Card profiles](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html).
However, these simple cards may not support the target client in demonstrating the full CRD
capabilities of its system. The CRD client test suite also allows testers to 
[provide a template for the responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses)
for Inferno to provide back, including directives that determine details of the actual responses
based on the request. This way, testers can configure the responses to match the patients, orders,
and other relevant details of their system allowing a complete demonstration. See the
[documentation on controlling Inferno's simulated CRD responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses)
for complete details.

In either case, Inferno will check that the responses it generates to send back to the client are
conformant and systems will not pass the tests if they are not.

#### SMART Authentication for FHIR API Access

In order to access the client's FHIR API, Inferno will need to be a
[trusted service](https://cds-hooks.hl7.org/STU2/#trusting-cds-services)
registered as a client using details provided within the suite at time of execution.

### Simulated CRD Server in the CRD Client v2.2.1 Suite

The Da Vinci CRD Client v2.2.1 Test Suite provides basic CDS services for
[the six hooks contained in the implementation guide](https://hl7.org/fhir/us/davinci-crd/2.2.1/hooks.html).
While it mostly follows the same approach as [the simulation in the v2.0.1 suite](#simulated-cds-services-in-the-crd-client-v201-suite),
there are are several key differences described here.

#### Prefetch and Additional Data Retrieval

In the 2.2.1 version of the CRD IG, clients are [required to support prefetch](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#prefetch)
and to be able to provide the complete minimal data set via this mechanism. Inferno therefore assumes
that the requisite data is included and does not attempt to retrieve any data in the minimal data set
during a hook invocation. However, clients are still required to allow servers to access data via FHIR
APIs. Inferno will request during a hook invocation FHIR resources outside the standard prefetch data
set that it needs to validate other requirements, including
- The Organization resource that represents the payer associated with the prefetched Coverage via its `payor` element.
- Parent Location resources of those provided via prefetch via the `partOf` element.

#### Multiple Service Endpoints

The v2.2.1 suite defines two sets of services rooted at the following discovery endpoints:
- `custom/crd_client_v221/cds-services`: requests the complete [standard prefetch](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#standard-prefetch)
  dataset. The discovery response returned can be found [here](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/v2.2.1/cds-services-v201.json).
- `custom/crd_client_v221/prefetch-subset/cds-services`: requests a subset of the [standard prefetch](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#standard-prefetch)
  dataset using non-standard prefetch keys to allow clients to demonstrate their ability to react to the
  service definitions provided by payers. The discovery response returned can be found [here](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/v2.2.1/cds-services-prefetch-subset-v221.json).

#### Hook Configuration Options

As advertised in by the discovery endpoints, Inferno's simulation includes support for a limited number of
hook configuration options specified in hook requests, including:
- requested version via the `davinci-crd.requestedVersion` extension: clients can request [v2.0.1 simulation](#simulated-cds-services-in-the-crd-client-v201-suite)
  behavior. Note that the requests are still evaluated by the tests against v2.2.1 requirements.
- coverage-info response filter via the `coverage-info` key in the `davinci-crd.configuration`
  extension: if set to `false` Inferno's simulation will not return any cards related to coverages,
  including cards with a `coverage-info` source type or topic, and coverage information and
  form completion responses in the `systemActions` list.

## Testing Limitations

Much of what the CRD IG specifies is optional, such as which hooks and resource
types to support. These tests try to provide testers with an opportunity to
exercise as much of their systems as they wish and validate that the exercised
behaviors are correct. However, not all areas of the IG are exercised.

Specific general limitations across all versions include:
- This suite does not implement any payer business logic, so testers must either
  use [Inferno's simple hard-coded responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
  or [tell Inferno how to return responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses)
  that are comformant and drive the desired behavior in the tested system.
- The tests cannot verify that a client is able to consume the received
  decision support. Testers should consider this requirement to be verified
  through attestation and should not represent their systems as having passed
  these tests if this requirement is not met.
- Not all requirements are verified.

### Additional v2.0.1 Client Suite Limitations

- hook configuration is not tested.

### Additional v2.2.1 Client Suite Limitations

- The [logical models defined in the v2.2.1 CRD IG](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/artifacts.html#structures-logical-models)
  contain some bugs and inconsistencies. Known issues have been reported
  and workarounds have been added to the test kit. If you identify an error
  reported by Inferno that you believe is inaccurate, please report it
  using [GitHub Issues](https://github.com/inferno-framework/davinci-crd-test-kit/issues).