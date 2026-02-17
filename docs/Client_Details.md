## Simulated CDS Services
This suite provides basic CDS services for
[the six hooks contained in the implementation guide](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html).
The discovery endpoint is located at `custom/crd_client/cds-services` under the root Inferno deployment
address, e.g., `https://inferno.healthit.gov/suites/custom/crd_client/cds-services` for the publicly
hosted deployment of this test kit.

The rest of this section provides details on the implementation of these services and the expected
behavior when invoked by tested clients.

### Data Fetching During Hook Invocations

#### CRD and CDS Hooks requirements around data availablity and access

The CRD IG requires that Clients make data beyond the details provided in the hook request body available
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
- CRD Servers may not always need all of this information in all circumstances.
- CRD Clients may not have all of this information, e.g., the performing practitioner may not be known at order time.
- Specific CRD servers may not be authorized to access all of this data.

Two mechanisms for making the data available are specified:
- [Prefetch](https://hl7.org/fhir/us/davinci-crd/STU2/foundation.html#prefetch), where the CRD Server indicates what
  data it will always need as a part of discovery and the client provides this information with the hook request.
- [FHIR Resource Access](https://hl7.org/fhir/us/davinci-crd/STU2/foundation.html#fhir-resource-access), where
  the CRD Server uses an access token provided in the hook request to make FHIR queries to get additional data.

CRD Clients must provide an access token for data access but are not required to support prefetch (though prefetch
may become required in later versions of the CRD spec).

#### Inferno simulated services behavior for data availability and access

Even though this information is not required to be available and accessible in all cases, these tests are designed
to allow CRD Clients to demonstrate that they can make the information captured in their system
available to the CRD Servers on which they invoke hooks. Therefore,
- Inferno [advertizes prefetch templates](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/routes/cds-services.json)
  requesting a subset of this data that clients can provide with the hook request if they support prefetch.
  Subsequent tests will check that the prefetched data is equivalent to what can be accessed via FHIR queries.
- When a client makes a hook invocation, Inferno will analyze the hook request and prefetched data and attempt to
  retrieve the rest of the available resources in the minimum data set. Subsequent tests will check that these
  requests all succeeded and fail if they did not. Testers will need to choose a hook invocation target and
  payer / user configuration that demonstrates this access.

#### Fetch interactions

Inferno performs individual reads for each resource identified. While this involves additional requests, support
for these read interactions is required by the CRD Client capability statement and the US Core Server Capability
Statement that it builds on. In practice clients may support and payers may use more efficient queries that
are not tested by Inferno.

The one exception is `Coverages`, which are obtained via the same search advertized in
[Inferno's prefetch templates](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/routes/cds-services.json).
  
#### Specific elements targeted

While the CRD STU2 IG does not provide precise definitions of the FHIR elements that constitute the minimum
data set, recent builds of the IG provide more explicit elements that represent the minimum data set as a part
of [minimal prefetch templates](https://build.fhir.org/ig/HL7/davinci-crd/en/Binary-CRDServices.html).
The elements indicated in those prefetch templates informed the set of elements that Inferno looks in to determine
what references to fetch.

Any literal reference, relative or absolute, Inferno will attempt to read using the provided access token.
Non-literal references will be ignored.

### CDS Hooks Responses

CRD Client test suite contains [basic logic to generate CDS Hooks responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
that meet each of the [CRD Card profiles](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html).
However, these simple cards may not support the target client in demonstrating the full CRD
capabilities of its system. The CRD Client test suite also allows testers to 
[provide a template for the responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses)
for Inferno to provide back, including directives that determine details of the actual responses
based on the request. This way, testers can configure the responses to match the patients, orders,
and other relevant details of their system allowing a complete demonstration. See the
[documentation on controlling Inferno's simulated CRD responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses)
for complete details.

In either case, Inferno will check that the responses it generates to send back to the client are
conformant and systems will not pass the tests if they are not.

### SMART Authentication for FHIR API Access

In order to access the client's FHIR API, Inferno will need to be a
[trusted service](https://cds-hooks.hl7.org/STU2/#trusting-cds-services)
registered as a client using details provided within the suite at time of execution.


