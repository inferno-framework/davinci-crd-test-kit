# Client Suite Implementation Details

The Da Vinci CRD Test Kit Client Suite validates the conformance of client
systems to the STU 2 version of the HL7® FHIR®
[Da Vinci Coverage Requirements Discovery Implementation Guide](https://hl7.org/fhir/us/davinci-crd/STU2/).

These tests are a **DRAFT** intended to allow CRD client implementers to perform
preliminary checks of their clients against CRD IG requirements and [provide
feedback](https://github.com/inferno-framework/davinci-crd-test-kit/issues)
on the tests. Future versions of these tests may validate other
requirements and may change the test validation logic.

## Technical Implementation

In this test suite, Inferno simulates a CRD payer server for the client under test to
interact with. The client will be expected to initiate requests to the server
and demonstrate its ability to react to the returned responses and also allow
Inferno to access. data using FHIR APIs. Over the course of these interactions,
Inferno will seek to observe conformant handling of CRD requirements.

This suite contains two groups of tests:
- The Hooks group receives and responds to incoming CDS Hooks requests from CRD clients
  and seeks to verify:
  - The ability of the client to initiate a CDS Hooks request for each hook (at least one)
  that the client supports
    - [appointment-book](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#appointment-book)
    - [encounter-start](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#encounter-start)
    - [encounter-discharge](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#encounter-discharge)
    - [order-select](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-select)
    - [order-sign](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-sign)
    - [order-dispatch](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-dispatch)
  - The ability of the client to process and display to the user information returned in CRD card types
    present in the CDS Hooks responses, including:
    - [External Reference](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#external-reference)
    - [Instructions](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#instructions)
    - [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information)
    - [Propose Alternate Request](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#propose-alternate-request)
    - [Additional Orders](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#identify-additional-orders-as-companionsprerequisites-for-current-order)
    - [Form Completion](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#request-form-completion)
    - [Create / Update Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#create-or-update-coverage-information)
    - [Launch SMART App](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#launch-smart-application)
- The FHIR API group makes FHIR requests to CRD Clients to verify that they support the
  FHIR interactions defined in the implementation guide.

All FHIR resources present in requests and responses, both FHIR and CDS Hooks, will be checked
for conformance to the CRD IG and CDS Hooks requirements individually and used in aggregate
to determine whether required features and functionality are present. HL7® FHIR® resources are
validated with the Java validator using `tx.fhir.org` as the terminology server.

## CDS Services
This suite provides basic CDS services for
[the six hooks contained in the implementation guide](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html).
The discovery endpoint is located at `custom/crd_client/cds-services` under the root Inferno deployment
address, e.g., `https://inferno.healthit.gov/suites/custom/crd_client/cds-services` for the publicly
hosted deployment of this test kit.

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

In order to access the client's FHIR API, Inferno will need to be registered as a client using
details provided within the suite at time of execution.

## Testing Limitations

Much of what the CRD IG specifies is optional, such as which hooks and resource
types to support. These tests try to provide testers with an opportunity to
exercise as much of their systems as they wish and validate that the exercised
behaviors are correct. However, not all areas of the IG are exercised. For example,
custom hook configuration is not tested.