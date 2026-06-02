# Da Vinci CRD Server v2.2.1 Test Suite Testing Instructions

This document provides a step-by-step guide for using the Da Vinci CRD Server v2.2.1 Test Suite to test
a **CRD server system**, including instructions for a [demonstration execution](#demonstration-execution).

## Pre-execution Setup and Required Information

Inferno needs to know 4 basic pieces of information to invoke a hook on a CRD server:
- **CRD server base URL**: the root discovery endpoint where Inferno will discover hook service details.
- **Discovery Authentication**: whether the discovery endpoint requires authentication.
- **Signature Algorithm**: which supported signing algorithm to use - `ES384` or `RS384`.
- **Hook Request Body**: the request contents to use when making the hook invocation.

For hook-specific testing, prepare request bodies that will cause the server to demonstrate the
response behavior you want Inferno to validate. If the server needs to retrieve FHIR resources
from Inferno while processing a hook, provide those resources in the **Mock EHR Data** input.
Once those details are available, test execution can start.

## Quick Start

To execute a simple set of tests targeting a single hook follow these steps:

1. Create a "Da Vinci CRD Server v2.2.1 Test Suite" session.
1. Select group "1 Discovery" from the list at the left and click the "RUN TESTS" button
   in the upper right.
1. In the inputs, provide the details gathered above and click the "SUBMIT" button. Inferno
   will make a discovery request, analyze the details and finish execution.
1. Select either group "2 Hook Response Demonstration" or the sub-group corresponding to the
   target hook under group "3 Hooks". The latter option will perform more in-depth
   verification related to the specific hook.
1. Click the "RUN TESTS" button in the upper right, provide the request body for Inferno
   to use for the invocation in the "Request body ..." input, and click the "SUBMIT" button.
1. Inferno will perform the invocation, analyze the response, and complete execution.

Review the results of the tests to get feedback on the conformance of the server to the
CRD specification.

## Additional Testing Options

The following groups and inputs can be used to expand the process described in the
[Quick Start](#quick-start) section into a complete set of tests.

### Testing Additional Hooks

Additional hooks can be tested in the same manner by selecting and running the associated
group as described in [Quick Start](#quick-start). For a complete run, exercise each supported
hook group under "3 Hooks": "3.1 appointment-book", "3.2 encounter-start",
"3.3 encounter-discharge", "3.4 order-select", "3.5 order-dispatch", and "3.6 order-sign".

### Cross-hook Requirements

Once groups associated with all supported hooks have been run, execute group
"3.7 Cross-Hook Response Validation" to confirm that cross-hook requirements
have been met. These tests use the requests made during other groups so cannot be run
before they have been run.

## Interpreting Results

A passing session means the server demonstrated conformant behavior for the discovery response
and the hook requests supplied during the run. Failures identify issues Inferno detected in the
request, response, or demonstrated CRD response behavior.

Skipped tests usually mean Inferno did not have enough demonstrated behavior to check
that requirement. Omitted tests represent testing requirements that are not relevant
to the current system. Optional tests that do not pass still roll up to a passing
result, but they provide valuable feedback for the implementation. See
[Server Details](Server-Details) for implementation notes and current limitations.

## Demonstration Execution

To demonstrate test execution, see the instructions for
[running the Inferno client and server suites against each other](Running-Suites-Against-Each-Other).
