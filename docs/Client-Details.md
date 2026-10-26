# Client Suite Implementation Details

The Da Vinci CRD Test Kit contains suites validating the conformance of CRD clients
to two versions of the HL7® FHIR® Da Vinci Coverage Requirements Discovery Implementation Guide:
- [v2.0.1](https://hl7.org/fhir/us/davinci-crd/STU2)
- [v2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1)

These tests are a **DRAFT** intended to allow CRD client implementers to perform
preliminary checks of their clients against CRD IG requirements and [provide
feedback](https://github.com/inferno-framework/davinci-crd-test-kit/issues)
on the tests. Future versions of these tests may validate other
requirements and may change the test validation logic.

## Understanding CRD Client Testing in Inferno

### Client Testing Paradigm

To enable testing of CRD clients that [initiate requests](https://inferno-framework.github.io/docs/getting-started/paradigms#client-initiator-testing),
Inferno [simulates CRD service endpoints](#crd-server-simulation)
for CRD clients to initiate hook requests against (for the
[client v2.2.1 suite](#simulated-crd-server-in-the-crd-client-v221-suite) and
the [client v2.0.1 suite](#simulated-crd-server-in-the-crd-client-v201-suite)).
However, these endpoints will only respond successfully when Inferno can
associate the incoming request with an active testing session. The following
are key considerations for testers to be aware of when running these tests and
others that use this client testing paradigm:

- Inferno will only recognize requests when the test session is
  actively waiting. In the CRD client suites, these tests
  and their parent groups are marked with a "Tester-Initiated Exchange"
  badge. When these tests are running and active, they will display
  a "User Action Required" dialog that explains what Inferno expects
  to happen, how Inferno will respond, how to continue the tests, and other
  relevant details. If a "User Action Required" dialog is not displayed
  in your session, Inferno will not recognize any hook requests you make.
- "User Action Required" dialogs are active and waiting for incoming
  requests for the session for a set period of time (typically about 5
  minutes). The active time remaining is displayed at the bottom
  of the dialog. After the timer runs out, Inferno will stop waiting
  for requests and testers will need to click the "Cancel" button
  and restart the test run that timed out. Using the "Cancel"
  button is always an option if testers are unable to or do not
  want to complete the remaining steps for the current test.
- For CRD client tests, Inferno uses the `iss` claim in the payload
  of the JWT provided as the Bearer token to identify the session
  that the incoming message will be associated with. Testers will
  provide the value that the CRD client will send in this location
  as an input when running the Registration tests. CRD clients that
  cannot [send a JWT for authentication](https://cds-hooks.hl7.org/#trusting-cds-clients)
  will not be able to use these tests.

NOTE: because Inferno's simulated discovery endpoints are not session-dependent,
these restrictions do not apply to them. Discovery requests will always return the
same response and the endpoints are always active even when there is no waiting session.

#### Debugging Connectivity Issues

Until hook requests from the CRD client reach Inferno's CRD service endpoints
and get associated with an active session, they will not be visible within
the Inferno UI. If you are receiving error responses when sending requests
to Inferno or are otherwise unsure whether your requests are reaching Inferno,
compare the response you received to the following cases for help in
determining what might be happening:
- Non-FHIR, non-CDS response: Inferno's CRD endpoints will always
  return FHIR OperationOutcomes for errors and CDS responses on success.
  If something else was returned, double check the endpoint the
  request was sent to as it will not be an Inferno CRD endpoint.
  If you think it is an Inferno CRD endpoint that returned this
  anomalous response, [submit a GitHub issue](https://github.com/inferno-framework/davinci-crd-test-kit/issues)
  providing the specific request, the URL it was sent to, and the
  response.
- OperationOutcome response indicating that "Inferno could not find an
  active test run" in `issue.details.text`: Inferno received the
  request, but failed to associate it with the session. The details
  of the error message will help you determine what went wrong:
  - Unexpected target URL: The error message will contain the
    URL at which Inferno received the request, including the host
    and suite. If those details do not look right, the CRD client's
    configuration may need to be updated to point to the correct
    target Inferno host and suite.
  - "no identifier found": Indicates that the JWT Inferno expects to
    find as the Bearer token in the Authorization header was either
    not present or malformed in some way. Update the CRD client to
    send a JWT with the `iss` claim equal to the value configured
    in your Inferno session. If this is not possible, you will not
    be able to use these Inferno tests.
  - "identifier 'X' ... is not associated with a waiting session":
    Inferno found an `iss` in the JWT in the Bearer token, but no
    matching session was waiting. This could mean that the session
    was not waiting with an active "User Action Required" dialog
    that indicated it would respond to CRD requests or that the
    "User Action Required" dialog had expired. If neither fits
    your case, double check the target URL to make sure the
    request went to the Inferno host where your session is running.
  - "error encountered while determining the test run identifier":
    Your request is malformed in some way that Inferno does not
    handle well. Check your request and [submit a GitHub issue
    in this repository](https://github.com/inferno-framework/davinci-crd-test-kit/issues),
    providing the specific request, the URL it was sent to, and the
    response.
- Another OperationOutcome or CDS response: This could be an Inferno
  response to a request that was correctly associated with a session.
  You can confirm by using the technique described in the
  [Debugging Other Unexpected Responses](#debugging-other-unexpected-responses)
  section to see if the request got associated with the waiting test.
  If not, double check the target URL.

#### Debugging Other Unexpected Responses

Inferno's CRD service simulation attempts to be permissive and return
successful responses whenever possible even if the requests or the responses
are not themselves conformant and won't pass the tests. If you see
unexpected results and responses even when you think that requests
are correctly reaching Inferno and matching up with your session, you
can always see all requests that Inferno received and responded to
while waiting at a "User Action Required" dialog.

To see the requests received by Inferno and associated with the session
while a "User Action Required" dialog was active, select the test and
view the Requests tab. To do so, if the run is not already finished,
first either cancel the test run or continue and complete it using the
instructions, links, or buttons in the "User Action Required"
dialog. If you aren't sure which test to select, look for the test with
the blue "Tester-Initiated Exchange" badge within the executed group.
Containing groups will have it, too, and can be used to guide you to the
right test, but they will not have requests associated with them. Once
you've found the right test, all requests that Inferno received and
associated with the session while that "User Action Required" dialog
was active will be listed on the test's Requests tab with details of
the request received and Inferno's response. If you completed the test
run instead of canceling it, other tests may have requests associated
with them, but some, e.g., error responses, will not be listed on those
other tests.

### Tester-Provided Responses

When simulating a CRD server responding to a hook request, Inferno must
return CRD responses that follow a complex structure and can include
rich data in the form of FHIR resources. However, Inferno is not a payer
and does not have the data, knowledge, or business rules that would typically
be used to create a complete response to a hook request. This provides a
challenge for Inferno as it needs to be able to respond conformantly to
any conformant system that tests against it and do so with the full range of
CRD responses required by the specification to confirm complete conformance
and coverage.

The Inferno team considered two potential approaches to address this challenge:
1. Inferno-driven: Define tightly controlled scenarios that CRD clients would need to set
   up and use to demonstrate conformance.
2. Tester-driven: Ask testers to provide the responses that Inferno will use
   and have Inferno verify that they are conformant and complete.

The second option was chosen due to the risk in the first option of placing
unintended requirements upon CRD clients testing with Inferno and
the high cost to testers to set up very specific scenarios. The trade-off
is that testers now need to specify the response details for Inferno
in at least some cases to pass the tests.

Specifically, when responding to CRD hook invocations Inferno can either:

- Generate generic mocked responses that cover only basic cases, or
- Respond with tester-provided content, including more complex responses
  that may be tailored to specific details of the CRD client or the data or
  configuration that it holds.

Currently, tester must use tester-provided responses to satisfy
Coverage-Information extension must support requirements.

See the [Controlling Responses from Inferno's Simulated CRD Server](Controlling-Simulated-Responses)
page of this wiki for details on both the [mocked responses](Controlling-Simulated-Responses#mocked-responses) that Inferno
can generate and how Inferno [builds responses from tester-provided templates](Controlling-Simulated-Responses#tester-directed-custom-responses).

## Technical Implementation

For these suites, Inferno [simulates a CRD payer server](#crd-server-simulation)
for the CRD client to interact with. The client will be expected to initiate
requests to the server, allow Inferno to access data using FHIR APIs, and
demonstrate its ability to react to the returned responses. Over the course of these
interactions, Inferno will seek to observe conformant handling of CRD requirements as
defined in the targeted CRD version.

The client suites each contain two top-level groups:
- In the "Hook Invocation" group, CRD clients will register Inferno's simulated
  CRD discovery endpoint(s) against payer(s) and demonstrate invocations of
  the CRD-specified hooks ([v2.0.1](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html),
  [v2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html)) that they support.
  Support for features required across all hooks but not necessarily on each one will
  also be checked as a part of this group.
- In the "FHIR API" group, CRD clients will demonstrate that they can act as
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

## Must Support Tests

CRD clients are required to demonstrate support for some elements which appear only
under certain conditions. See the **[Client Must Support](Client-Must-Support)**
section for details on what Inferno checks for and the underlying requirements
that drive those tests.

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

##### CRD and CDS Hooks requirements around data availability and access

The CRD IG requires that clients make data beyond the details provided in the hook request body available
to servers so that payers can use it as a part of coverage determination. The IG lists the [minimum that
CRD clients need to make available](https://hl7.org/fhir/us/davinci-crd/STU2/foundation.html#additional-data-retrieval):

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
- Inferno [advertises prefetch templates](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/v2.0.1/cds-services-v201.json)
  requesting a subset of this data that clients can provide with the hook request if they support prefetch.
  Subsequent tests will check that the prefetched data is equivalent to what can be accessed via FHIR queries.
- When a client makes a hook invocation, Inferno will analyze the hook request and prefetched data and attempt to
  retrieve the rest of the available resources in the minimum data set. Subsequent tests will check that these
  requests all succeeded and fail if they did not. Testers will need to choose a hook invocation target and
  payer / user configuration that demonstrates this access.

##### Fetch interactions

Inferno performs individual reads for each resource identified. While this involves additional requests, support
for these read interactions is required by the CRD Client CapabilityStatement and the US Core Server CapabilityStatement
that it builds on. In practice, clients may support and payers may use more efficient queries that
are not tested by Inferno.

The one exception is `Coverages`, which are obtained via the same search advertised in
[Inferno's prefetch templates](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/v2.0.1/cds-services-v201.json).

These requests are made before Inferno returns the hook response. Each one fails if the server
does not respond within 10 seconds, so that a slow or unresponsive server cannot hold the response
indefinitely.

##### Specific elements targeted

While the CRD STU2 IG does not provide precise definitions of the FHIR elements that constitute the minimum
data set, recent builds of the IG provide more explicit elements that represent the minimum data set as a part
of [minimal prefetch templates](https://build.fhir.org/ig/HL7/davinci-crd/en/Binary-CRDServices.html).
The elements indicated in those prefetch templates informed the set of elements that Inferno looks in to determine
what references to fetch.

Inferno will attempt to read any literal reference, relative or absolute. The provided access token
will be sent when the reference is to a resource on the `fhirServer` indicated in the hook
request body; otherwise it will not be sent. Non-literal references will be ignored.

#### CDS Hooks Responses

The CRD client test suite contains [basic logic to generate CDS Hooks responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
that meet each of the [CRD Card profiles](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html).
However, these simple cards may not support the target client in demonstrating the full CRD
capabilities of its system. The CRD client test suite also allows testers to
[provide a template for the responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses)
for Inferno to provide back, including directives that determine details of the actual responses
based on the request. This way, testers can configure the responses to match the patients, orders,
and other relevant details of their system, allowing a complete demonstration. See the
[documentation on controlling Inferno's simulated CRD responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses)
for complete details.

In either case, Inferno will check that the responses it generates to send back to the client are
conformant and systems will not pass the tests if issues are identified.

#### SMART Authentication for FHIR API Access

In order to access the client's FHIR API, Inferno will need to be a
[trusted service](https://cds-hooks.hl7.org/STU2/#trusting-cds-services)
registered as a client using details provided within the suite at the time of execution.

### Simulated CRD Server in the CRD Client v2.2.1 Suite

The Da Vinci CRD Client v2.2.1 Test Suite provides basic CDS services for
[the six hooks contained in the implementation guide](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html).
While it mostly follows the same approach as [the simulation in the v2.0.1 suite](#simulated-crd-server-in-the-crd-client-v201-suite),
there are several key differences described here.

#### Prefetch and Additional Data Retrieval

In the 2.2.1 version of the CRD IG, clients are [required to support prefetch](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#prefetch)
and to be able to provide the complete minimal data set via this mechanism. Inferno therefore assumes
that the requisite data is included and does not attempt to retrieve any data in the minimal data set
during a hook invocation. However, clients are still required to allow servers to access data via FHIR
APIs. During a hook invocation, Inferno will perform FHIR read interactions to request resources outside
the standard prefetch data set that it needs to validate other requirements, including:
- The Organization resource that represents the payer associated with the prefetched Coverage via its `payor` element.
- Parent Location resources of those provided via prefetch through the `partOf` element.
- Resources referenced in must support elements that don't appear within the `context` or `prefetch`
  fields of the hook request.

Inferno makes these reads before returning the hook response, so when a hook request contains
many references to resources not included in the request or the CRD client's FHIR server responds
slowly, Inferno's response can be delayed. To bound the delay, every FHIR request Inferno makes
during a hook invocation, including the `Coverage` search made when no Coverage is prefetched, fails
if the server does not respond within 10 seconds. Once a server has timed out while
Inferno is reading must support references, Inferno makes no further must support reads from that
server for the rest of the hook request.

When requesting data, Inferno will only attempt to read literal references. It will use the Bearer
token provided in the `fhirAuthorization.access_token` field of the hook request as long as the
reference points to a resource on the `fhirServer` indicated in the hook request, as determined
by [Bundle reference resolution rules](https://hl7.org/fhir/R4/bundle.html#references). If the
reference refers to a resource on another FHIR server, Inferno does not include an access token
on the read request. Such reads do not count as evidence that Inferno can access data from the
CRD client's FHIR server during a hook request.

During the "User Access Level Scoping" scenario, Inferno will attempt to read an additional
tester-specified resource. Whereas the other resources listed above must be accessible, Inferno
will expect this resource to be available only during the hook request made by the full-access user.

#### Multiple Service Endpoints

The v2.2.1 suite defines two sets of services rooted at the following discovery endpoints:
- `custom/crd_client_v221/cds-services`: requests the complete [standard prefetch](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#standard-prefetch)
  data set. The discovery response returned can be found [here](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/v2.2.1/cds-services-v221.json).
- `custom/crd_client_v221/prefetch-subset/cds-services`: requests a subset of the [standard prefetch](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#standard-prefetch)
  data set using non-standard prefetch keys to allow clients to demonstrate their ability to react to the
  service definitions provided by payers. The discovery response returned can be found [here](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/v2.2.1/cds-services-prefetch-subset-v221.json).

#### Hook Configuration Options

As advertised by the discovery endpoints, Inferno's simulation includes support for a limited number of
hook configuration options specified in hook requests, including:
- requested version via the `davinci-crd.requestedVersion` extension: clients can request [v2.0.1 simulation](#simulated-crd-server-in-the-crd-client-v201-suite)
  behavior. Note that the requests are still evaluated by the tests against v2.2.1 requirements.
- coverage-info response filter via the `coverage-info` key in the `davinci-crd.configuration`
  extension: if set to `false`, Inferno's simulation will not return any cards related to coverages,
  including cards with a `coverage-info` source type or topic, and coverage information and
  form completion responses in the `systemActions` list.

#### Matching Requests in the User Access Level Scoping Scenario

The "User Access Level Scoping" scenario compares the two hook requests it receives to confirm that
they represent the same workflow action. Both must invoke the same hook for the same patient on the
same service endpoint, and must describe matching content:
- order hooks: the elements of each order that describe what was ordered - `code`,
  `medicationCodeableConcept`, `medicationReference`, `codeCodeableConcept` and `codeReference`. For
  the order types that carry no such element, `payload` is used for CommunicationRequest,
  `lensSpecification` for VisionPrescription, and `foodPreferenceModifier`, `excludeFoodModifier`,
  `oralDiet`, `supplement` and `enteralFormula` for NutritionOrder.
- `appointment-book`: the `actor` references of the appointment's [PrimaryPerformer participants](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-appointment-base-definitions.html#Appointment.participant:PrimaryPerformer).
- encounter hooks: the encounter's `class` and `type`.

Each of these elements is compared in full, so two resources differ if any detail within one of them
differs. Order and appointment hooks provide the resources in the request context, while encounter
and `order-dispatch` hooks provide only a reference and the resources are taken from the prefetch
data. A request that provides neither the resources nor any of the elements above fails the test.

## Testing Limitations

Much of what the CRD IG specifies is optional, such as which hooks and resource
types to support. These tests try to provide testers with an opportunity to
exercise as much of their systems as they wish and validate that the exercised
behaviors are correct. However, not all areas of the IG are exercised.

Limitations across all versions include:
- This suite does not implement any payer business logic, so testers must either
  use [Inferno's simple hard-coded responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
  or [tell Inferno how to return responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses)
  that are conformant and drive the desired behavior in the tested system.
- The tests cannot verify that a client is able to consume the received
  decision support. Testers should consider this requirement to be verified
  through attestation and should not represent their systems as having passed
  these tests if this requirement is not met.
- Versioned references are not supported.
- Not all requirements are verified.

### Additional v2.0.1 Client Suite Limitations

- Hook configuration is not tested.

### Additional v2.2.1 Client Suite Limitations

- The [logical models defined in the v2.2.1 CRD IG](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/artifacts.html#structures-logical-models)
  contain some bugs and inconsistencies. Known issues have been reported
  and workarounds have been added to the test kit. If you identify an error
  reported by Inferno that you believe is inaccurate, please report it
  using [GitHub Issues](https://github.com/inferno-framework/davinci-crd-test-kit/issues).
