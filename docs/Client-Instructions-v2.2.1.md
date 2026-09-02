# Da Vinci CRD Client v2.2.1 Test Suite Testing Instructions

This document provides a step-by-step guide for using the Da Vinci CRD Client v2.2.1 Test Suite to test
a **CRD client system**, including instructions for a [demonstration execution](#demonstration-execution)
against the public [CRD client reference implementation](https://crd-request-generator.davinci.hl7.org/).

## Pre-execution Setup and Required Information

### Minimum Requirements

To run against the Da Vinci CRD Client v2.2.1 Test Suite, a CRD client implementation must at minimum
- Be configured to make CRD hook requests to one of the suite's
  [simulated CDS Hooks endpoints](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#multiple-service-endpoints).
- [Authenticate](https://cds-hooks.hl7.org/2026Jan/en/#trusting-cds-clients) each hook request
  by sending a JWT with a known `iss` (issuer) claim in the payload.

### Passing Requirements

Additional configuration and information is needed to demonstrate conformance to all tested requirements.
In order to pass all tests in the suite, a CRD client implementation must
- Be configured to make CRD hook requests to both suite's
  [simulated CDS Hooks endpoints](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#multiple-service-endpoints).
  Inferno will use requests to both endpoints to verify the client's ability to satisfy
  both [the complete standard prefetch as well as a subset of it](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#ci-c-found-25).
- Associate each of these endpoints with a FHIR Organization id representing the payer
  that provides the insurance coverage and is responsible for determining coverage requirements.
  Inferno will use this information to verify that Hook calls are made against the
  [correct payer's service](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformancedetails.html#ci-c-dev-26).
- Sign JWTs sent as a part of hook request authentication and provide the JSON Web Key Set (JWKS)
  containing the key used for the signature, either as a URL where it is publicly hosted or the
  raw JWKS as JSON.
- Support the capabilities of the US Core Server Capability Statement for one of the following versions:
  - [US Core 3.1.1](http://hl7.org/fhir/us/core/STU3.1.1/CapabilityStatement-us-core-server.html)
  - [US Core 6.1.0](http://hl7.org/fhir/us/core/STU6.1/CapabilityStatement-us-core-server.html)
  - [US Core 7.0.0](http://hl7.org/fhir/us/core/STU7/CapabilityStatement-us-core-server.html)
- Be able to provide Inferno with a long-lived or refreshable access token to use when verifying support for
  the US Core FHIR API. This can come from the hook request itself, or be provided via a test input.

Additionally, because the [mocked responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
created by Inferno's simulation do not demonstrate all of the must support elements on the
[coverage-information extension](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-ext-coverage-information.html),
testers will need to provide some [custom responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses)
that demonstrate all of those elements as required by the
[must support definition](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-6).

## Quick Start

To execute a simple set of tests targeting a single hook using Inferno's mocked response,
you will need the following:
1. The `iss` (issuer) claim of the JWT that will be sent in the `Authorization` header
   of CDS Hooks requests made by the tested client. This is used to identify incoming requests
   and associate them with the test session.
2. The JSON Web Key Set (JWKS) used to sign the JWT sent in the `Authorization` header
   of CDS Hooks request. This can be either a URL where it is publicly hosted or the
   raw JWKS as JSON. This can be skipped, but the tests will not completely pass without it.
3. The FHIR Organization ids associated in the tested system with the following Inferno
   CRD server discovery endpoints. These can be skipped, but the tests will not completely pass
   without them.
   - `custom/crd_client_v221/cds-services`   
   - `custom/crd_client_v221/prefetch-subset/cds-services`

Once you have that information, follow these steps:

1. Create a "Da Vinci CRD Client v2.2.1 Test Suite" session using your chosen version of US Core.
1. Select the "1.1 Registration" group from the list at the left and and click
   the "RUN TESTS" button in the upper right.
1. Provide the information gathered above into the associated inputs. Only the
   **CRD JWT Issuer** input, which will be used by Inferno to identify
   CDS Hook invocation requests coming from the client under test, is strictly required
   to run the tests. However, the tests will not fully pass without all the inputs.
1. Click the "SUBMIT" button to verify the registration details. You can continue even if the
   tests fail, e.g., because no JWKS was provided.
1. Select the sub-group under "1.2 Hooks" that corresponds to a hook implemented by the
   tested client and click the "RUN TESTS" button in the upper right.
1. Select the response types Inferno should respond with under the **Response types to return
   from [hook name] hook requests** input (the options depend on which hook was chosen).
1. Click the "SUBMIT" button and a "User Action Required" dialog will be appear asking for
   hook invocations to be made against the Inferno's simulated service endpoint.
1. Make one or more hook invocations of the target hook against Inferno's simulated service
   endpoint, including in the request a JWT with the `iss` field equal to the value provided
   in the **CRD JWT Issuer** input. If you make a request with a different `iss`
   value, Inferno will not be able to link the request to the test session and will not
   respond to or analyze the request.
1. Once all requests have been made, click the link in the "User Action Required" dialog
   and Inferno will analyze the requests to determine whether they were conformant. The
   responses mocked by Inferno based on any successful requests will also be analyzed for
   conformance.
1. Assuming that at least one request was successfully made, a second "User Action Required"
   dialog will appear asking for confirmation that the returned cards were displayed to the
   user within the tested system. Respond using the appropriate link to complete the tests.

## Additional Testing Options

The following groups and inputs can be used to expand the process described in the
[Quick Start](#quick-start) section into a complete set of tests.

### Testing Additional Hooks

Additional hooks can be tested in the same manner by selecting and running the associated
group as described in [Quick Start](#quick-start).

### Customizing Responses

The "Custom response template for [hook name] hook requests" input can be used to customize the hook
responses to better fit the configuration of the tested client system. When this input is populated,
the corresponding "Response types to return from [hook name] hook requests" input is ignored. See the
[documentation on controlling Inferno's simulated CRD responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses)
for complete details on how to use these inputs.

### Cross Hook Verification

After running one or more hook groups, run group "1.3 Cross Hook" to check if the client
has met requirements that must be demonstrated across all hook requests, but aren't required for each hook invocation.
For example, clients must have received and attested to display support of the [Coverage Information](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type)
response type including all must support elements on the [coverage-information extension](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-ext-coverage-information.html)
which Inferno must have observed during the testing.

Re-run these tests to re-evaluate after making additional requests with adjusted responses
(see [Customizing Responses](#customizing-responses)) so that the requisite support is
demonstrated.

### Long-running Hook Requests

Run group "1.4 Long-running Hook Request" to test that users can continue their workflow during long-running
responses. Inferno will pause for a specified number of seconds (at least 5) before responding to a hook
invocation made during this test to allow testers to verify and demonstrate this capability in the tested
client system.

### FHIR API Testing

Group 2 "FHIR API" focuses on the FHIR API of the tested client outside of the context of a CDS Hook
invocation. It tests the complete US Core server read and search FHIR API based on the requirements
of the US Core version selected during session creation. Additionally, it checks that
updates triggered by [Coverage Information](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type)
response types are visible externally using the client's FHIR API. Thus, these tests should always
be run after the hook tests.

A primary requirement for running the FHIR API tests is an access token for Inferno to send in the
`Authorization` header that will grant the access needed to verify API support. The token provided
in the most recent CDS Hooks invocation will be used by default. However, these should be short-lived
per the [CDS Hooks specification](https://cds-hooks.hl7.org/2026Jan/en/#passing-the-access-token-to-the-cds-service)
potentially only remaining active during the hook invocation itself. Since the FHIR API tests are performed
outside of a hook invocation and are long-running due to their comprehensive nature, the token provided
on in the hook request may not be usable for these tests. If the token is not usable, testers
may override the token and provide an appropriate token (and other details such as a refresh token and corresponding
endpoints) in the "OAuth Credentials" input of the the FHIR API tests. Note that the token
must have the same access scopes as those provided during the hook requests.

## Interpreting Results

Due to [limitations of these tests](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Overview#test-scope-and-limitations),
passing this test suite in its entirety [does not prove conformance to the specification](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Overview#conformance-criteria--interpreting-results).
Additionally, some of the capabilities tested by this suite are optional including many of the hooks
and response types, meaning that a conformant system will not necessarily be able to pass all tests
in the suite.

With those caveats, a passing execution of this suite would include:
- Passing the corresponding hook group under the 1.2 Hooks group for each hook supported.
- Passing all other groups, including
  - 1.1 Registration
  - 1.3 Cross Hook
  - 1.4 Long-running Hook Request
  - 2 FHIR API

## Demonstration Executions

To see how executing these tests against a real system works in practice, you
can execute these tests against one of the following public reference implementations.

NOTES:
- The reference implementation will need to make requests to Inferno, meaning that these
  demonstrations will most easily be run using the publicly-hosted tests on `inferno.healthit.gov`
  against the publicly-hosted reference implementation. You can also choose to run both
  Inferno and the reference implementation locally.
- When executing on `inferno.healthit.gov`, know that a fixed session identifier is used to
  recognize incoming requests, so if multiple people are running a particular demonstration
  on `inferno.healthit.gov` at the same time, results will be unpredictable as the sessions
  compete to associate requests. If you are seeing odd behavior, consider trying again at
  another time.

### Da Vinci BR Provider reference implementation

The [Da Vinci BR Provider](https://br-provider.davinci.hl7.org/) reference implementation is
actively maintained and can be used to demonstrate most of the CRD hooks. The following
partial test run is not expected to fully pass, but demonstrates the steps needed in
a realistic UI to interact with the Inferno CRD client tests.

1. Create a "Da Vinci CRD Client v2.2.1 Test Suite" session using any "US Core Version".
1. Select the "Da Vinci BR Provider Reference Implementation" option from the Preset dropdown in the upper left.
1. In a separate tab, navigate to https://br-provider.davinci.hl7.org/ and login (no password
   needed) as a practitioner (any).
1. Configure the connection to Inferno's simulated CRD server by:
   1. Clicking the gear icon in the upper right to open the settings dialog.
   1. Select the "Payor" tab
   1. Use the "Server" dropdown to select the "Custom" option.
   1. In the "CDS Services URL" input, put `https://inferno.healthit.gov/suites/custom/crd_client_v221/cds-services`.
   1. Click the "Bypass payor-handled check" box.
   1. Click the "Save" button and close the dialog to complete the setup.
1. Select a patient (any) to open their chart.
1. In the Inferno tab, run group "1.2.2 encounter-start" without any changes to the inputs.
   When the dialog appears indicating Inferno is ready to receive requests, return to the
   br-provider tab.
1. Click the "Start Encounter" button in the far upper right of the chart window. This will
   trigger hook requests and within a few seconds, you should see some cards displayed within
   the frame on the right.
1. In the Inferno tab, click the link in the dialog to continue the tests. Inferno will take
   a few moments to analyze the interactions and check them for conformance. After it has done
   so, a new dialog will appear asking the tester to confirm that the returned responses
   were displayed or otherwise made available to the user appropriately, including
   a instructions card, a external reference card, and the coverage-information system action.
   Determining the right response is a judgement call, but return to the br-provider tab
   and decide what you see and make the corresponding attestation in Inferno. At the time of
   this writing, only the two cards were clearly displayed, but the coverage-information
   system action was not.
1. In Inferno, run group "1.2.3 order-select" without any changes to the inputs.
   When the dialog appears indicating Inferno is ready to receive requests, return to the
   br-provider tab.
1. Select an order (any) from the "Add Order" dropdown and click the "+ Add" button to the right
   of the dropdown. This will trigger hook requests and within a few seconds, you should see
   updated cards displayed in the frame at the right.
1. In the Inferno tab, click the link in the dialog to continue the tests. Inferno will take
   a few moments to analyze the interactions and check them for conformance. After it has done
   so, a new dialog will appear asking the tester to confirm that the returned responses
   were displayed or otherwise made available to the user appropriately, including
   a instructions card, a external reference card, and the coverage-information system action.
   Determining the right response is a judgement call, but return to the br-provider tab
   and decide what you see and make the corresponding attestation in Inferno. At the time of
   this writing, only the two cards were clearly displayed, but the coverage-information
   system action was not.
1. In Inferno, run group "1.2.4 order-sign" without any changes to the inputs.
   When the dialog appears indicating Inferno is ready to receive requests, return to the
   br-provider tab.
1. Click the "Sign all Orders" button at the bottom of the chart frame (scroll down). On the
   next screen, click the the "Confirm & Sign" button. This will trigger hook requests and
   within a few seconds, you should see updated cards displayed in the frame at the right.
1. In the Inferno tab, click the link in the dialog to continue the tests. Inferno will take
   a few moments to analyze the interactions and check them for conformance. After it has done
   so, a new dialog will appear asking the tester to confirm that the returned responses
   were displayed or otherwise made available to the user appropriately, including
   a instructions card, a external reference card, and the coverage-information system action.
   Determining the right response is a judgement call, but return to the br-provider tab
   and decide what you see and make the corresponding attestation in Inferno. At the time of
   this writing, the two cards were clearly displayed, and the details from the coverage-information
   system action (e.g., "covered" indication) were displayed with the list of linked orders.
1. In Inferno, run group "1.2.5 order-dispatch" without any changes to the inputs.
   When the dialog appears indicating Inferno is ready to receive requests, return to the
   br-provider tab.
1. Click the "Dispatch Orders" button within the "Linked Orders" box. This will trigger
   hook requests and within a few seconds, you should see updated cards displayed in the
   frame at the right.
1. In the Inferno tab, click the link in the dialog to continue the tests. Inferno will take
   a few moments to analyze the interactions and check them for conformance. After it has done
   so, a new dialog will appear asking the tester to confirm that the returned responses
   were displayed or otherwise made available to the user appropriately, including
   a instructions card, a external reference card, and the coverage-information system action.
   Determining the right response is a judgement call, but return to the br-provider tab
   and decide what you see and make the corresponding attestation in Inferno. At the time of
   this writing, the two cards were clearly displayed, and the details from the coverage-information
   system action (e.g., "covered" indication) were displayed with the list of linked orders.
1. In Inferno, run group "1.2.6 encounter-discharge" without any changes to the inputs.
   When the dialog appears indicating Inferno is ready to receive requests, return to the
   br-provider tab.
1. Click the "Finish Encounter" button at the bottom of the chart frame. This will trigger
   hook requests though the results won't be displayed even once the page is fully loaded.
1. In the Inferno tab, click the link in the dialog to continue the tests. Inferno will take
   a few moments to analyze the interactions and check them for conformance. After it has done
   so, a new dialog will appear asking the tester to confirm that the returned responses
   were displayed or otherwise made available to the user appropriately, including
   a instructions card, a external reference card, and the coverage-information system action.
   Determining the right response is a judgement call, but return to the br-provider tab
   and decide what you see and make the corresponding attestation in Inferno. At the time of
   this writing, no card details were displayed, but the systemAction details are still available
   with the order.

Those instructions demonstrate the bulk of the CRD ordering workflow. Not all tests are
expected to pass. You can also
- Login as a part to schedule an appointment and verify the appointment-book hook behavior
  against Inferno.
- Use the options to specify [custom responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses),
  e.g., to demonstrate changing coverage-information details for the order across
  different hooks or different orders.
- Execute some of the other scenario tests in Inferno and trigger a request from the
  reference implementation.

### crd-request-generator reference implementation (old)

The old [crd-request-generator public CRD reference client](https://crd-request-generator.davinci.hl7.org/),
supports the order-sign hook and can be used to demonstrate suite execution with the
following steps. Note that this reference implementation has not been updated for the
2.2.1 version of the CRD IG so many failures are expected during this execution. However,
it can give you a sense for what executing the Inferno tests against a client system will
look like.

1. Create a "Da Vinci CRD Client v2.2.1 Test Suite" session using the default "US Core Version",
   which will not be used.
1. Select the "CRD Request Generator Reference Implementation" option from the Preset dropdown in the upper left.
1. Select the "1.2.4 order-sign" hook group on the left menu and click on the *RUN TESTS* button in the upper right.
1. Select the response types Inferno should respond with under the **Response types to return
   from order-sign hook requests** input and click the "SUBMIT" button.
1. A "User Action Required" dialog will appear asking for order-sign hook invocations to be
   made against Inferno's simulated CRD server.
1. Open the [reference client](https://crd-request-generator.davinci.hl7.org/) in another tab/browser.
1. Click the gear button in the upper right to open the configuration screen and update
   the following fields:
   - *CRD Server*: Inferno's CDS Server discovery endpoint, which will be everything before the
   last slash in the endpoint displayed in the "User Action Required" dialog,
   e.g., `https://inferno.healthit.gov/suites/custom/crd_client_v221/cds-services`.
   - *Order Sign Rest End Point*: the location of the `order-sign` hook endpoint relative to the *CRD Server*, which will be everything after the last slash in the endpoint displayed in the
   "User Action Required" dialog, e.g., `order-sign-service`.
1. Click the "save configuration" button in the lower left to close the configuration screen.
1. Click the "Patient Select" button to open patient and order selection.
1. In the first row, click the "Request" drop down on the right side and select "E0250 (Device Request)"
   and then click the box to the left with "**Name** William Oster" to select the patient and order.
1. Click the "Submit to CRD and Display Cards" button and cards will display on the right side
   of the screen where you can interact with them.
1. Back in Inferno, click the link in the "User Action Required" dialog to continue the tests. A second
   "User Action Required" dialog will appear asking for confirmation that the returned cards were
   displayed properly. Click the appropriate link based on your interactions with the client in the
   previous step.
1. The Inferno tests will complete. NOTE: many tests are expected to fail as this reference implementation
   has not been updated to use the v2.2.1 version.

## Inferno Client vs Server Execution

For another way to demonstrate test execution without an accompanying UI, see the instructions for
[running the Inferno client and server suites against each other](Running-Suites-Against-Each-Other).