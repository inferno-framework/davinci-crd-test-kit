# Server Suite Implementation Details

The Da Vinci CRD Server Suite validates the conformance of server systems 
to the STU 2 version of the HL7® FHIR® 
[Da Vinci Coverage Requirements Discovery Implementation Guide](https://hl7.org/fhir/us/davinci-crd/STU2/).

These tests are a **DRAFT** intended to allow CRD server implementers to perform 
preliminary checks of their servers against CRD IG requirements and [provide 
feedback](https://github.com/inferno-framework/davinci-crd-test-kit/issues) 
on the tests. Future versions of these tests may validate other 
requirements and may change the test validation logic.

## Technical Implementation

In this test suite, Inferno simulates a CRD client system and will make CDS Hooks
invocations against the tested CRD server system. Over the course of these requests,
Inferno will seek to observe conformant handling of invocations for supported
[CRD hooks](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html) and
the demonstration of cards and actions conforming to the supported
[CRD card profiles](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html).

This suite contains three groups of tests:
1. The *Discovery* group validates a CRD server's discovery response.
2. The *Demonstrate A Hook Response* group validates that the server
    can respond to a single hook invocation and return conformant cards.
3. The *Hooks* group makes one or more CDS Hooks calls for each hook
    type that the tester provides request bodies for. It then validates that the
    responses are conformant and cover the full range of cards as
    required by the hook type.

All requests and responses will be checked for conformance to the CRD
IG and CDS Hooks requirements individually and used in aggregate to determine whether
required features and functionality are present. HL7® FHIR® resources are 
validated with the Java validator using `tx.fhir.org` as the terminology server.

### Trusting Inferno's CDS Client

As specified in the [CDS Hooks Spec](https://cds-hooks.hl7.org/2.0/#trusting-cds-clients),
each time a CDS Client transmits a request to a CDS Service which requires authentication,
the request MUST include an Authorization header presenting the JWT as a “Bearer” token:
`Authorization:  Bearer {{JWT}}`

Inferno self-issues the JWT for each CDS Service call and details on the issuer and the JWKS
are provided during suite execution. They will follow the following pattern:

- **ISS**: `<inferno base>/custom/crd_server`
- **JWK Set Url**: `<inferno base>/custom/crd_server/jwks.json`

Inferno base is the address of the Inferno deployment, such as `https://inferno.healthit.gov/suites`
for the publicly hosted deployment of this test kit.

### CDS Hooks Requests

Because the business logic that determines the details of responses
Is outside of the CRD specification and will vary between implementers, testers
are required to provide the requests that Inferno will make to the tested server.
This way, testers do not need to configure Inferno-specific details, but instead
tell Inferno what details to send that will allow the server to demonstrate its
full CRD capabilities. Inferno will check that the requests provided are
conformant and systems will not pass the tests if they are not.

## Testing Limitations

Much of what the CRD IG specifies is optional, such as which hooks and resource
types to support. These tests try to provide testers with an opportunity to
exercise as much of their systems as they wish and validate that the exercised
behaviors are correct. However, not all areas of the IG are exercised. For example,
custom hook configuration is not tested, and neither is the ability of servers to
request additional data from the client using FHIR APIs.