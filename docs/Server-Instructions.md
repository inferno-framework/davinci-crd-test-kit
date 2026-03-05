# Da Vinci CRD Test Kit: Server Testing Instructions

This document provides a step-by-step guide for using the Da Vinci CRD Server Test Suite to test
a **CRD server system**, including instructions for a [demonstration execution](#demonstration-execution)
against the public [CRD server reference implementation](https://crd.davinci.hl7.org/).

## Quick Start

Inferno needs to know 4 basic pieces of information to invoke a hook on a CRD Server:
- **CRD server base URL**: the root discovery endpoint where Inferno will discover hook service details.
- **Discovery Authentication**: whether the discovery endpoint requires authentication.
- **Signature Algorithm**: which supported signing algorithm to use - `ES384` or `RS384`.
- **Hook Request Body**: the request contents to use when making the hook invocation.
Once those details are available, teste execution can start.

To execute a simple set of tests targeting a single hook follow these steps:

1. Create a Da Vinci CRD Server Suite v2.0.1 session.
1. Select group "1 Discovery" from the list at the left and and click the "RUN TESTS" button
   in the upper right.
1. In the inputs, provide the details gathered above and click the "SUBMIT" button. Inferno
   will make a discovery request, analyze the details and finish execution.
1. Select either group "2 Demonstrate A Hook Response" or the sub-group corresponding to the
   target hook under group "3 Hook Tests". The latter option will perform more in-depth
   verification related to the specific hook.
1. Click the "RUN TESTS" button in the upper right, provide the requst body for Inferno
   to use for the invocation in the "Request body ..." input, and click the "SUBMIT" button.
1. Inferno will perform the invocation, analyze the response, and complete execution.

Review the results of the tests to get feedback on the conformance of the server to the
CRD specification.

## Additional Testing Options

The following groups and inputs can be used to expand the process described in the
[Quick Start](#quick-start) section into a complete set of tests.

### Testing Additional Hooks

Additional hooks can be tested in the same manner by selecting and running the associated
group as described in [Quick Start](#quick-start).

### Cross-hook Requirements

Once groups associated with all supported hooks have been run, execute group
"3.7 Required Card Response Validation" to confirm that cross-hook requirements
have been met. These tests use the requests made during other groups so cannot be run
before they have been run.

## Demonstration Execution

If you would like to try out the order-sign hook invocation tests against
[the public CRD reference server](https://crd.davinci.hl7.org/),
you can do so using the following steps:

1. Create a Da Vinci CRD Server Suite v2.0.1 session.
1. Select the *CRD Server RI* option from the Preset dropdown in the upper left.
1. Click the "RUN ALL TESTS" button in the upper right and click "SUBMIT"
1. Inferno will perform several hook invocations and complete the test run. Note that all
   tests may not pass.

## Inferno Client vs Server Execution

For another way to demonstrate test execution, see the instructions for
[running the Inferno client and server suites against each other](Running-Suites-Against-Each-Other).