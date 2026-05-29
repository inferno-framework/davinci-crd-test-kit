# Da Vinci CRD Server v2.2.1 Test Suite Testing Instructions

This document provides a step-by-step guide for using the "Da Vinci CRD Server v2.2.1 Test Suite" to test
a **CRD server system**, including instructions for a [demonstration execution](#demonstration-execution)
against the public [CRD server reference implementation](https://crd.davinci.hl7.org/).

## Pre-execution Setup and Required Information

### Minimum Requirements

To run against the "Da Vinci CRD Server v2.2.1 Test Suite", a CRD server implementation must at minimum:

- Expose a CDS Hooks discovery endpoint at `{baseURL}/cds-services`, where **CRD server base URL**
  is the value of `{baseURL}`.
- Advertise at least one CRD CDS service in the discovery response, including the service `id`, `hook`,
  and CRD version declaration required by CRD v2.2.1.
- Accept CDS Hooks POST requests from Inferno at the service endpoint formed as
  `{baseURL}/cds-services/{service.id}`.
- Return a valid CDS Hooks response with HTTP 200 for at least one tester-supplied hook request.

If the discovery endpoint or CDS Hooks service endpoints require authentication, configure the tested server
to trust Inferno as a CDS client. Inferno signs discovery and hook requests with a JWT whose `iss` is the
Inferno base URL and whose `jku` points to Inferno's JWKS endpoint. The signing key details are described in
[Server Testing Details](Server-Details#trusting-infernos-cds-client).

### Passing Requirements

Additional setup and representative test data are needed to demonstrate all behavior checked by the suite.
In order to pass the relevant tests for a server's advertised CRD capabilities, a tester should be prepared to:

- Provide hook request bodies for every CRD hook that the server supports and that the tester wants Inferno
  to validate.
- Provide request bodies that cause the server to demonstrate supported response types, including required
  Coverage Information `systemActions` for primary hooks.
- Provide **Mock EHR Data** when the server needs to retrieve resources from Inferno's simulated FHIR endpoint
  during hook processing.
- Provide request bodies that exercise v2.2.1 behavior for `coverage-info` configuration, unknown
  `configuration` values, unknown `context` values, and unknown CDS Hooks elements when those tests apply.
- Run group "3.7 Cross-Hook Response Validation" after the relevant hook groups have produced responses.

Because CRD allows many hooks, order resources, and response types to be optional, a server can be conformant
without passing every hook or optional response-type test in this suite. A passing test session is meaningful
only for the hooks and behaviors that were exercised.

### Information to Gather

Before starting a session, gather the following information:

- **CRD server base URL**: the root URL that Inferno will use to call `{baseURL}/cds-services`.
- **Discovery endpoint requires authentication?**: whether Inferno must include a signed JWT when calling
  discovery.
- **JWT Signing Algorithm**: the algorithm Inferno should use when signing request JWTs, either `ES384` or
  `RS384`.
- **CDS Services JWKS kid**: optional `kid` value selecting the Inferno signing key to use.
- **Service ID for the service that implements the `[hook]` hook**: optional if group "1 Discovery" has already
  discovered exactly which service IDs implement the target hook.
- **Request body or bodies for invoking the `[hook]` hook**: one JSON CDS Hooks request body, or a JSON array
  of request bodies, tailored to the tested server's business rules.
- **Mock EHR Data**: optional FHIR Bundle containing resources Inferno should expose through its simulated
  FHIR endpoint while hook requests are running.

## Quick Start

Use this path for a minimal run against a single hook.

1. Create a "Da Vinci CRD Server v2.2.1 Test Suite" session.
1. Select group "1 Discovery" from the list at the left and click the "RUN TESTS" button.
1. Populate **CRD server base URL**, **Discovery endpoint requires authentication?**,
   **JWT Signing Algorithm**, and **CDS Services JWKS kid** if needed.
1. Click the "SUBMIT" button. Inferno will call discovery, validate the response, and save discovered service
   IDs for later groups.
1. Select either group "2 Demonstrate a Hook Response" for a smoke test or the specific hook group under
   group "3 Hook Tests" for deeper hook-specific validation.
1. Populate **Request body to use for the "Demonstrate a Hook Response" test** or the relevant
   **Request body or bodies for invoking the `[hook]` hook** input with a single CDS Hooks request body. If
   the discovery group was not run, or if Inferno cannot infer the service ID, also populate
   **Service ID to use for the "Demonstrate a Hook Response" test** or the relevant
   **Service ID for the service that implements the `[hook]` hook** input.
1. Leave **Mock EHR Data** as the default empty Bundle unless the tested server will query Inferno's simulated
   FHIR endpoint while processing the hook request.
1. Click the "SUBMIT" button. Inferno will invoke the hook, keep the simulated FHIR endpoint available during
   processing, analyze the request and response, and complete the selected group.

A minimal input set for an unauthenticated `order-sign` run looks like this:

| Input | Example value |
| --- | --- |
| **CRD server base URL** | `https://payer.example.org/crd` |
| **Discovery endpoint requires authentication?** | `No` |
| **JWT Signing Algorithm** | `ES384` |
| **Service ID for the service that implements the `order-sign` hook** | Leave blank when discovery found one matching service, or provide a service ID such as `order-sign-service` |
| **Request body or bodies for invoking the `order-sign` hook** | A single CDS Hooks `order-sign` JSON request body |
| **Mock EHR Data** | `{"resourceType":"Bundle","type":"collection"}` |

## Additional Testing Options

The following groups and inputs can be used to expand the process described in
[Quick Start](#quick-start) into a complete set of tests.

### Complete Run

For a complete run against the server capabilities under test:

1. Run group "1 Discovery".
1. Review the discovered services and decide which advertised CRD hook services are in scope for the session.
1. Run group "2 Demonstrate a Hook Response" with a single representative request if a quick end-to-end
   response demonstration is useful. This group is not a substitute for hook-specific validation.
1. Under group "3 Hook Tests", run each hook group that corresponds to a supported CRD service:
   - "3.1 appointment-book"
   - "3.2 encounter-start"
   - "3.3 encounter-discharge"
   - "3.4 order-select"
   - "3.5 order-dispatch"
   - "3.6 order-sign"
1. For each hook group, provide request bodies that cover the server behavior to be tested. Primary hook groups
   should include scenarios that demonstrate required Coverage Information behavior.
1. Run group "3.7 Cross-Hook Response Validation" after all relevant hook groups have completed.
1. Review skipped tests. Skipped tests usually indicate behavior that the system still needs to demonstrate,
   but Inferno did not receive enough information to make that determination.

### Populating Hook Request Inputs

Hook-specific groups accept either one JSON object or a JSON array of objects in the relevant
**Request body or bodies for invoking the `[hook]` hook** input.

Use a single JSON object for a minimal run:

```json
{
  "hook": "order-sign",
  "context": {
    "userId": "Practitioner/example",
    "patientId": "example",
    "draftOrders": {
      "resourceType": "Bundle",
      "type": "collection",
      "entry": []
    }
  }
}
```

Use a JSON array for a more complete run that sends multiple requests to the same service:

```json
[
  {
    "hook": "order-sign",
    "context": {
      "userId": "Practitioner/example",
      "patientId": "example",
      "draftOrders": {
        "resourceType": "Bundle",
        "type": "collection",
        "entry": []
      }
    }
  },
  {
    "hook": "order-sign",
    "extension": {
      "davinci-crd.configuration": {
        "coverage-info": false
      }
    },
    "context": {
      "userId": "Practitioner/example",
      "patientId": "example",
      "draftOrders": {
        "resourceType": "Bundle",
        "type": "collection",
        "entry": []
      }
    }
  }
]
```

These examples show the shape of the input. Real request bodies should include the hook-specific `context`
content and FHIR resources needed to trigger meaningful server responses. The repository's
`execution_scripts/prefetch/*_complete-prefetch.json` files provide examples of more complete hook request
bodies.

Inferno overwrites `hookInstance`, `fhirServer`, and `fhirAuthorization.access_token` when making hook
requests. The tested server should use the supplied `fhirServer` and access token if it needs to retrieve
additional resources during hook processing.

### Populating Mock EHR Data

Use **Mock EHR Data** when the server will query Inferno's simulated FHIR endpoint. The input must be a FHIR
Bundle. A minimal Bundle is enough when the server does not need to retrieve additional resources:

```json
{
  "resourceType": "Bundle",
  "type": "collection",
  "entry": []
}
```

For a complete run, include resources that are referenced by hook request context, prefetch resources, or
responses that the server returns. For example, if an `order-dispatch` response references dispatched orders,
the referenced resources should be available in the hook request, prefetch, or **Mock EHR Data** so Inferno can
resolve and validate them.

### Manual Continuation

The **Require acknowledgement of completed hook requests?** input controls whether Inferno continues
automatically after hook invocation or waits for the tester to continue manually. Select "Continue on user
acknowledgement" when the server needs additional time to make FHIR API calls against Inferno's simulated
FHIR endpoint after the CDS Hooks response is returned.

### Cross-Hook Requirements

Once groups associated with all supported hooks have been run, execute group "3.7 Cross-Hook Response
Validation" to confirm that cross-hook requirements have been met. These tests use requests and responses
from earlier hook groups, so they cannot provide meaningful results before the relevant hook groups have run.

The cross-hook group checks behavior that must be demonstrated across the session, including Coverage
Information `systemActions` and Must Support elements on the coverage-information extension.

## Interpreting Results

Due to [limitations of these tests](Overview#test-scope-and-limitations), passing this test suite in its
entirety [does not prove conformance to the specification](Overview#conformance-criteria--interpreting-results).
Additionally, many hooks and response types are optional in CRD, so a conformant server will not necessarily
pass tests for every hook or optional response type.

Use the following guidance when reviewing results:

- A passing group means Inferno validated the behavior it observed in that group.
- A skipped test usually means the system needs to demonstrate the behavior, but Inferno did not receive enough
  information to make that determination, such as no request body or no matching service ID.
- An omitted test usually means the test is not relevant to run in the situation given prior observed behavior,
  such as an optional response type that was not returned.
- A failing test identifies a required structure, response, or behavior that Inferno observed as invalid.
- Warnings and informational messages often identify optional data, follow-up checks, or details that explain
  why a later test skipped or omitted.

With those caveats, a passing execution for the tested server capabilities would include:

- Passing group "1 Discovery".
- Passing each hook group under group "3 Hook Tests" that corresponds to an advertised CRD service included in
  the session.
- Passing group "3.7 Cross-Hook Response Validation" after all relevant hook groups have run.
- Confirming that skipped tests are explained by missing inputs or evidence.

## Limitations

The "Da Vinci CRD Server v2.2.1 Test Suite" depends on tester-supplied hook requests to exercise the server's
business logic. Inferno cannot determine which orders, appointments, encounters, patients, or coverage details
will cause a particular server to return a specific CRD response type.

Important limitations include:

- Passing results are limited to the hook requests and response scenarios supplied during the session.
- Optional hooks and response types that are not exercised are not proven to be supported.
- Inferno's simulated FHIR endpoint serves only the resources provided in **Mock EHR Data** and does not model
  all production EHR FHIR server behavior.
- The suite validates observed CDS Hooks and CRD structures, but it does not independently confirm payer
  business rules or coverage determinations.
- Additional technical limitations are described in [Server Testing Details](Server-Details#testing-limitations).

## Demonstration Execution

To demonstrate test execution, see the instructions for
[running the Inferno client and server suites against each other](Running-Suites-Against-Each-Other).
