# Running the CRD Client and Server Suites Against Each Other

During development and debugging, it can be useful to run the client and server suites
against each other to confirm behavior, design decisions, or bug fixes. The following
instructions can be used to do so. These instructions do not work when running the
test kit locally within Docker due to networking restrictions when running without a
dedicated hostname.

## v2.0.1

1. Start a "Da Vinci CRD Client v2.0.1 Test Suite" session.
1. Choose the "Run Against the CRD Server Suite" preset from the drop down in the upper left.
1. Run group "1.1 Client Registration". It should pass.
1. In another tab, start a "Da Vinci CRD Server v2.0.1 Test Suite" session.
1. Choose the "Run Against the CRD Client Suite" preset from the drop down in the upper left.
1. Run group "1 Discovery". It should pass.
1. Repeat the following steps for each hook you want to test:
   1. In the client session, run group "1.2.x <hook name>" leaving the inputs as is. A
      "User Action Required" dialog will appear indicating that Inferno is waiting for the
      hook invocation.
   1. In the server session, run the corresponding group "3.x <hook name>" leaving the inputs
      as is.
   1. Once the server test are complete, return to the client tests and click the link
      in the "User Action Required" dialog indicating requests are complete to continue the
      tests.
   1. A second "User Action Required" dialog will appear asking you to attest that the returned
      responses were displayed. Choose your response based on the results of the response
      evaluation in the server tests.
1. Run client group "1.3 Card Must Support" and Server group "3.7 Required Card Response
   Validation" to complete the server tests.

Notes:
- The server preset contains requests for all hooks, so any can be tested.
- The execution uses the mocked CRD cards created by Inferno.
- While the server tests do not include a simlulated FHIR API, the client present includes
  inputs for testing the FHIR API group against the public Inferno reference server. However,
  these tests will largely fail since the public reference server is read-only meaning that
  the update tests will fail.

## v2.2.1

Running the v2.2.1 suites against each other requires 2 server sessions, one connecting to each
of the [v2.2.1 service endpoints](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#multiple-service-endpoints).

1. Start a "Da Vinci CRD Client v2.2.1 Test Suite" session using US Core 3.1.1
1. Apply preset "Run against the CRD Server Suite"
1. Run client group "1.1 Registration"
1. Create a "Da Vinci CRD Server v2.2.1 Test Suite" session in a new tab that will connect to the "complete prefetch" endpoints
1. Apply preset "Run against the CRD Client Suite"
1. Run server group "1 Discovery"
1. Create a second "Da Vinci CRD Server v2.2.1 Test Suite" session in a new tab that will connect to the "subset prefetch" endpoints
1. Apply preset "Run Against the CRD Client Suite's Prefetch Subset Services"
1. Run server group "1 Discovery"
1. Follow the following procedure for each of the hook groups:
   1. In the client session, run group "1.2.x <hook name>".
   1. When a "User Action Required" dialog appears, switch to the "complete prefetch" server session and run group "3.x <hook name>"
   1. Once complete, switch to the "subset prefetch" server session and run group "3.x <hook name>"
   1. Once complete, return to the client session and click the link in the "User Action Required" dialog to continue. Attest to the display of cards when the next "User Action Required" dialog appears.
1. Run client group "1.3 Cross Hook".
1. Run server group "3.7 Cross-Hook Response Validation" in both server sessions.

Some tests will fail, including
- TLS tests in the client suite (1.2.x.3.08) and server suites (1.01) will fail when executed in a local system.
- Client tests 1.2.x.3.01 validating that the hook requests structure and content will fail with errors
  on 4 requests each because the server suite purposefully sends non-conformant requests with unexpected
  fields to verify that the server ignores them.

### Additional Optional Steps for Long-running Hook Request

1. In the client session, run group "1.4 Long-running Hook Request" with no changes to the inputs.
1. In the "complete prefetch" server session, run group "2 Hook Response Demonstration" with no
   changes to the inputs.
1. Note that a "User Action Required" dialog will appear in the server session with no option to
   continue other than to cancel. This is expected because it is waiting for the client session's
   simulated CRD server to respond. That simulated CRD server is pausing for 5 seconds before
   responding.
1. After 5 seconds, the "User Action Required" dialog in the server session will disappear and the
   tests will complete.
1. Return to the client session and a new "User Action Required" asking for an attestation that
   the user's workflow could continue during the long-running request. Attest "true" because
   you had the option of cancelling Inferno's tests.

All tests should pass.

### Additional Optional Steps for FHIR API Testing

1. In the "subset prefetch" server session, run group "2 Hook Response Demonstration", with
   the following changes to inputs:
   - Update the **Mock EHR Data** input with the contents of the [stress-test-Bundle.json](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/server/endpoints/mock_ehr/stress-test-Bundle.json)
     file. This contains a complete set of US Core data. NOTE: its size introduces a small amount of lag into the Inferno UI
     when the input dialog is open.
   - Update the "Require acknowledgement of completed hook requests?" input to have the "Continue on user acknowledgement"
     option selected.
2. Once a "User Action Required" dialog appears, run client group "2 FHIR API". This will run for a while.
3. Once complete, return to the server session and click the link to complete the tests.

Some tests will fail, including:
- Client test 2.1.1.01 requiring TLS will fail when executed in a local system.
- Client test 2.1.2.01 will fail because the CRD client simulation in the Server suite does not
  automatically update the Bundle with resource updates in `systemActions`.
- Client test 2.1.11.10 will fail due to an expected conformance issue (this assumes that US Core version 3.1.1 was chosen at client session creation)
- The server tests will fail as expected because no responses were sent by the client suite.
