# Running the CRD Client and Server Suites Against Each Other

During development and debugging, it can be useful to run the client and server suites
against each other to confirm behavior, design decisions, or bug fixes. The following
instructions can be used to do so:

1. Start a "Da Vinci CRD Client Test Suite" session.
1. Choose the "Inferno CRD Server Suite" preset from the drop down in the upper left.
1. Run the Client Registration test group. It should pass.
1. Run the Hooks > Appointment Book test group leaving the inputs as is. A
   "User Action Dialog" will appear indicating that Inferno is waiting for the
   `appointment-book` hook invocation.
1. In another tab, start a "Da Vinci CRD Server Test Suite" session.
1. Choose the "Inferno CRD Client Suite" preset from the drop down in the upper left.
1. Run the Discovery test group. It should pass.
1. Run the Demonstrate A Hook Response test. It should pass
1. Return to the client suite and click the link to continue the tests.
1. When the attestation wait dialog appears, return to the server tests and look in test
   **2.04** "All service responses contain valid cards and optional systemActions"
   for the CDS hooks request made and look at the response to verify that the
   indicated cards are present. Attest accordingly in the client suite to complete the tests.

Notes:
- The server preset contains requests for all hooks, so other hooks can be tested as well.
- The execution uses the mocked CRD cards created by Inferno.
- While the server tests do not include a simlulated FHIR API, the client present includes
  inputs for testing the FHIR API group against the public Inferno reference server. However,
  these tests will largely fail since the public reference server is read-only meaning that
  the update tests will fail.