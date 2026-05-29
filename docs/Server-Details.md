# Server Suite Implementation Details

The Da Vinci CRD Test Kit contains suites validating the conformance of server systems
to two versions of the HL7® FHIR® Da Vinci Coverage Requirements Discovery Implementation Guide:
- [v2.0.1](https://hl7.org/fhir/us/davinci-crd/STU2)
- [v2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1)

These tests are a **DRAFT** intended to allow CRD server implementers to perform
preliminary checks of their servers against CRD IG requirements and [provide
feedback](https://github.com/inferno-framework/davinci-crd-test-kit/issues)
on the tests. Future versions of these tests may validate other
requirements and may change the test validation logic.

## Technical Implementation

In these suites, Inferno simulates a CRD client system and makes CDS Hooks invocations
against the tested CRD server system. Over the course of these requests, Inferno seeks
to observe conformant handling of invocations for supported CRD hooks
([v2.0.1](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html),
[v2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html)) and the
demonstration of cards and actions conforming to the supported CRD response types
([v2.0.1](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html),
[v2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html)).

The server suites each contain three top-level groups:
1. The "Discovery" group validates a CRD server's discovery response.
1. The v2.0.1 "Demonstrate A Hook Response" group and the v2.2.1
   "Hook Response Demonstration" group validate that the server can respond to
   a single hook invocation and return conformant cards and actions.
1. The v2.0.1 "Hook Tests" group and the v2.2.1 "Hooks" group make
   one or more CDS Hooks calls for each hook type
   that the tester provides request bodies for. It then validates that the responses
   are conformant and cover the response behavior required by the hook type.

All requests and responses are checked for conformance to the targeted CRD IG and
CDS Hooks requirements individually and used in aggregate to determine whether
required features and functionality are present. HL7® FHIR® resources are validated
with the Java validator using `tx.fhir.org` as the terminology server. CDS Hooks
request and response objects may also be checked using the validator against defined
logical models in versions that support them, such as
[v2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/artifacts.html#structures-logical-models).

### Trusting Inferno's CDS Client

As specified in the [CDS Hooks Spec](https://cds-hooks.hl7.org/2.0/#trusting-cds-clients),
each time a CDS client transmits a request to a CDS Service which requires authentication,
the request MUST include an Authorization header presenting the JWT as a Bearer token:
`Authorization: Bearer {{JWT}}`

Inferno self-issues the JWT for each CDS Service call and details on the issuer and the JWKS
are provided during suite execution. They follow these patterns:

| Suite | ISS | JWK Set URL |
| --- | --- | --- |
| v2.0.1 | `<inferno base>/custom/crd_server` | `<inferno base>/custom/crd_server/jwks.json` |
| v2.2.1 | `<inferno base>/custom/crd_server_v221` | `<inferno base>/custom/crd_server_v221/jwks.json` |

Inferno base is the address of the Inferno deployment, such as
`https://inferno.healthit.gov/suites` for the publicly hosted deployment of this test kit.

### CDS Hooks Requests

Because the business logic that determines the details of responses is outside of the CRD
specification and will vary between implementers, testers are required to provide the requests
that Inferno will make to the tested server. This way, testers do not need to configure
Inferno-specific details, but instead tell Inferno what details to send that will allow the
server to demonstrate its full CRD capabilities. Inferno checks that the requests provided are
conformant and systems will not pass the tests if they are not.

While Inferno is making hook requests, it can also expose a simulated FHIR API backed by the
resources in the **Mock EHR Data** input. This lets a tested CRD server retrieve additional
information from Inferno's simulated CRD client during hook processing.

### CRD Server v2.0.1 Suite

The Da Vinci CRD Server v2.0.1 Test Suite targets
[CRD STU 2.0.1](https://hl7.org/fhir/us/davinci-crd/STU2). It validates discovery,
basic hook invocation behavior, request structure, response card/action structure,
and support for CRD response types that can be demonstrated through tester-supplied
hook request bodies.

### CRD Server v2.2.1 Suite

The Da Vinci CRD Server v2.2.1 Test Suite targets
[CRD v2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1). It follows the same overall
workflow as the v2.0.1 suite and adds checks for v2.2.1-specific behavior including:
- CRD version declarations in discovery through the `davinci-crd.version` extension.
- Configuration option declarations in discovery, including `coverage-info` options for primary hooks:
  `appointment-book`, `order-sign`, and `order-dispatch`.
- Required Coverage Information system actions for primary hooks when the request resource does not
  already contain a coverage-information extension.
- Handling of the `coverage-info=false` configuration option when advertised as supported.
- Tolerance of unknown configuration values, unknown context values, and unknown CDS Hooks fields.
- Demonstration of coverage-information extension must support elements across the test session.
- Demonstration that the billing-options extension is not required for the server to respond.

## Testing Limitations

Much of what the CRD IG specifies is optional, such as which hooks and resource
types to support. These tests try to provide testers with an opportunity to
exercise as much of their systems as they wish and validate that the exercised
behaviors are correct. However, not all areas of the IG are exercised.

General limitations across all server versions include:
- Inferno is unable to determine what requests will result in specific kinds
  of responses from the server under test, such as Instructions or Coverage Information.
  As a result, the tester must supply the request bodies that will cause the system under
  test to return the desired response types.
- Inferno's simulated FHIR API is limited to the resources supplied in the **Mock EHR Data**
  input and does not model all behavior of a production EHR FHIR server.
- The ability of a CRD server to request additional FHIR resources is not exhaustively tested.

### Additional v2.0.1 Server Suite Limitations

- Hook configuration is not tested.

### Additional v2.2.1 Server Suite Limitations
- The server suite is not configured to validate responses using FHIR logical models, and
  instead uses custom logic within the tests.  Future versions may leverage the logical
  models provided by CRD to standardize the validation of this content.

The following requirements are not currently tested:
- `conf-8`: CRD servers SHALL NOT depend on or set expectations for the
  inclusion of any data elements not marked as mandatory (min cardinality >= 1)
  or mustSupport in those profiles.
- `found-29`: Servers SHALL use prefetch expressions in the manner described
  below if those data elements are relevant to their coverage determination or
  other decision support.
- `resp-25`: Regardless of the content, this "Coverage Information" response
  type SHALL NOT use a card.
- `resp-35`: However, CRD servers SHALL NOT send a systemAction to update the
  order unless something is new or changed.
- `resp-43`: If the CRD server encounters technical issues that prevent it from
  determining a coverage, prior auth, or documentation requirement response
  (e.g. due to internal communication issues, authorization failure, temporary
  unavailability of the CRD client's FHIR API, etc.), it SHALL indicate
  "indeterminate" in the appropriate element with a reason code of technical and
  additional details in the reason.text.
- `resp-44`: If the CRD server is unable to resolve the patient for a reason
  other than technology failure, the Coverage Information SHALL indicate
  "not-covered" in 'coverage' with a reason code of no-member-found.
- `resp-45`: If the CRD server is able to resolve the patient but they do not
  have active coverage or cannot resolve to a single coverage, the Coverage
  Information SHALL indicate "not-covered" with a reason of either
  coverage-not-found or no-active-coverage, as appropriate.
