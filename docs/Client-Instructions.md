# Da Vinci CRD Test Kit: Client Testing Instructions

This document provides a step-by-step guide for using the Da Vinci CRD Client Test Suite to test
a **CRD client system**, including instructions for a [demonstration execution](#demonstration-execution)
against the public [CRD client reference implementation](https://crd-request-generator.davinci.hl7.org/).

## Quick Start

To execute a simple set of tests targeting a single hook using Inferno's mocked response,
follow these steps:

1. Create a Da Vinci CRD Client Suite v2.0.1 session using the default "SMART App Launch Version",
   which will not be used.
1. Select the "1.1 Client Registration" group from the list at the left and and click
   the "RUN TESTS" button in the upper right.
1. Provide the "CRD JWT Issuer (required)" input, which will be used by Inferno to identify
   CDS Hook invocation requests coming from the client under test. You can also provide
   the "CRD JSON Web Key Set (JWKS)" as a URL or raw key set, which is required for Inferno
   to perform complete JWT verification, but is not required for execution.
1. Click the "SUBMIT" button to verify the registration details. You can continue even if the
   tests fail, e.g., because no JWKS was provided.
1. Select the sub-group under "1.2 Hooks" that corresponds to a hook implemented by the
   tested client and click the "RUN TESTS" button in the upper right.
1. Select the response types Inferno should respond with under the "Response types to return
   from [hook name] hook requests" input (the options depend on which hook was chosen).
1. Click the "SUBMIT" button and a "User Action Required" dialog will be appear asking for
   hook invocations to be made against the Inferno's simulated service endpoint.
1. Make one or more hook invocations of the target hook against Inferno's simulated service
   endpoint, including in the request a JWT with the `iss` field equal to the value provided
   in the "CRD JWT Issuer (required)" input. If you make a request with a different `iss`
   value, Inferno will not be able to link the request to the test session and will not
   respond or analyze the request.
1. Once all requests have been made, click the link in the "User Action Required" dialog
   and Inferno will analyze the requests to determine whether they were conformant.
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

The "Custom response for [hook name] hook requests" input can be used to customize the hook
responses to better fit the configuration of the tested client system. When this input is populated,
the corresponding "Response types to return from [hook name] hook requests" input is ignored. See the
[documentation on controlling Inferno's simulated CRD responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses)
for complete details on how to use these inputs.

### Card Must Support

After running one or more hook groups, run group "1.3 Card Must Support" to check if the client
has received and attested to support for all of the required cards ([External Reference](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#external-reference)
and [Instructions](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#instructions))
and demonstrated the display of all of the must support elements in the [coverage-information extension](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information.html)
when returned on [Converage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information) actions.

Re-run these tests to re-evaluate after making additional requests with adjusted responses
(see [Customizing Responses](#customizing-responses)) so that the requisite support is
demonstrated.

### FHIR API Testing

Group "2 FHIR API" focuses on the FHIR API of the tested client outside of the context of a CDS Hook
invocation. It focuses on API requirements that go beyond the bsae US Core API requirements that
are included in CRD STU 2. 

When starting the CRD Client Suite session, choose the appropriate version of the SMART
specification in the "SMART App Launch Version" suite option.

Running the tests require 4 types of inputs:
- **FHIR Endpoint (required)**: the base FHIR url
- **EHR Launch Credentials**: SMART client details corresponding to the version of SMART chosen
  when starting the session.
- **[ResourceType] Resources**: FHIR resource of the [ResourceType] that Inferno will use to
  perform an `update` interaction.
- **[ResourceType] IDs**: comma-separated lists of FHIR resource ids of the [ResourceType] that
  Inferno will use to perform a `read` interaction.

NOTE: the resources and resource IDs for testing reads and updates are not required, but if
no details or provided, those tests will be skipped.

To run them, follow these steps:
1. Choose group "2 FHIR API" and click the "RUN ALL TESTS" button in the upper right.
1. Provide the inputs as detailed above and click the "SUBMIT" button to start the test execution.
1. A "User Action Required" dialog will appear asking for the tested client system to perform
   an EHR launch sequence for Inferno. Perform the launch using the indicated details.
1. A second "User Action Required" dialog will appear asking for the tested client system to
   authorize access. Click the link and perform the authorization for the configured scopes.
1. Once authorization is complete, Inferno will submit FHIR API requests and verify the responses.

Once the test execution completes, review the test results for feedback on the tested system's
support for the required APIs.

## Demonstration Execution

If you would like to try out the order-sign hook invocation tests against
[the public CRD reference client](https://crd-request-generator.davinci.hl7.org/),
you can do so using the following steps:

1. Create a Da Vinci CRD Client Suite v2.0.1 session using the default "SMART App Launch Version",
   which will not be used.
1. Select the *CRD Request Generator RI* option from the Preset dropdown in the upper left.
1. Select the "1.2.6 order-sign" hook group on the left menu and click on the *RUN TESTS* button in the upper right.
1. Select the response types Inferno should respond with under the "Response types to return
   from order-sign hook requests" input and click the "SUBMIT" button.
1. A "User Action Required" dialog will appear asking for order-sign hook invocations to be
   made against Inferno's simulated CRD Server.
1. Open the [reference client](https://crd-request-generator.davinci.hl7.org/) in another tab/browser.
1. Click the gear button in the upper right to open the configuration screen and update
   the following fields:
   - *CRD Server*: Inferno's CDS Service discovery endpoint, which will be everything before the
   last slash in the endpoint displayed in the "User Action Required" dialog,
   e.g., `https://inferno.healthit.gov/suites/custom/crd_client/cds-services`.
   - *Order Sign Rest End Point*: the location of the `order-sign` hook endpoint relative to the *CRD Server*, which will be everything after the last slash in the endpoint displayed in the
   "User Action Required" dialog, e.g., `order-sign-service`.
1. Click the gear button in the upper right again to close the configuration screen.
1. Click the "Patient Select" button to open patient and order selection.
1. In the first row, click the "Request" drop down on the right side and select "E0250 (Device Request)"
   and then click the box to the left with "**Name** William Oster" to select the patient and order.
1. Click the "Submit to CRD and Display Cards" button and cards will display on the right side
   of the screen where you can interact with them.
1. Back in Inferno, click the link in the "User Action Required" dialog to continue the tests. A second
   "User Action Required" dialog will appear asking for confirmation that the returned cards were
   displayed properly. Click the appropriate link based on your interactions with the client in the
   previous step. NOTE: the client currently will not display the "coverage-information" systemAction.
1. The Inferno tests will complete. NOTE: the tests may not completely pass.

## Inferno Client vs Server Execution

For another way to demonstrate test execution without an accompanying UI, see the instructions for
[running the Inferno client and server suites against each other](Running-Suites-Against-Each-Other).