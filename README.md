# Da Vinci Coverage Requirements Discovery (CRD) Test Kit

This is an [Inferno](https://github.com/inferno-community/inferno-core) test kit
for the [Da Vinci Coverage Requirements Discovery (CRD) FHIR Implementation
Guide v2.0.1](https://hl7.org/fhir/us/davinci-crd/STU2).

It contains test suites to test the two actors defined by the CRD specification:
- [CRD
  Client](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html):
  responsible for initiating CDS Hooks calls and consuming received decision
  support. It is also responsible for returning data requested by the CRD Server
  needed to provide that decision support.
- [CRD
  Server](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-server.html):
  responsible for responding to CDS Hooks calls and responding with appropriate
  decision support.

This test kit is [open
source](https://github.com/inferno-framework/davinci-crd-test-kit#LICENSE) and
freely available for use or adoption by the Health IT community including EHR
vendors, health app developers, and testing labs.

## Status

These tests are a **DRAFT** intended to allow CRD implementers to perform
preliminary checks of their implementations against the CRD IG requirements and
provide feedback on the tests. Future versions of these tests may validate other
requirements and may change how these are tested.

Additional details on the IG requirements that underlie this test kit can be
found in this [CRD testing note](docs/crd-testing-notes.md). The document
includes the requirements extracted from the IG and specifies the ones that are
not testable.

## Test Scope and Limitations

Documentation of the current tests and their limitations can be found in each
suite's (client and server) description when the tests are run.

### Test Scope

At a high-level, the tests check:

- **Client Suite**:
  - The ability of a CRD client to initiate CDS Hooks calls.
  - The ability of a CRD client to support the FHIR interactions defined in the
    implementation guide.
- **Server Suite**:
  - The ability of a CRD server to return a valid response when invoking its
    discovery endpoint.
  - The ability of a CRD server to return a valid response when invoking a
    supported hook, including producing the required response types across all
    hooks invoked.

### Limitations

- **Client Suite**:
  - This suite does not implement any payer business logic, so the responses to
    hook calls are simple hard-coded responses.
  - The tests cannot verify that a client is able to consume the received
    decision support. Testers should consider this requirement to be verified
    through attestation and should not represent their systems as having passed
    these tests if this requirement is not met.
  - Hook configuration is not tested.
- **Server Suite**:
  - Inferno is unable to determine what requests will result in specific kinds
    of responses from the server under test (e.g., what will result in
    Instructions being returned vs. Coverage Information). As a result, the
    tester must supply the request bodies that will cause the system under test
    to return the desired response types.
  - The ability of a CRD server to request additional FHIR resources is not
    tested.
  - Hook configuration is not tested.

## How to Run

Use either of the following methods to run the suites within this test kit. If
you would like to try out the tests but don’t have a CRD implementation, the
test home pages include instructions for trying out the tests, including

- For server testing: a [public CRD server reference
  implementation](https://crd.davinci.hl7.org/) ([code on
  github](https://github.com/HL7-DaVinci/CRD?tab=readme-ov-file))
- For client testing: a [public CRD client reference
  implementation](https://crd-request-generator.davinci.hl7.org/) ([code on
  github](https://github.com/HL7-DaVinci/CRD?tab=readme-ov-file))

Detailed instructions can be found in the suite descriptions when the tests are
run.

### ONC Hosted Instance

You can run the CRD test kit via the [ONC
Inferno](https://inferno.healthit.gov/test-kits/davinci-crd/) website by
choosing the “Da Vinci Coverage Requirements Discovery (CRD) Test Kit”.

### Local Inferno Instance

- Download the source code from this repository.
- Open a terminal in the directory containing the downloaded code.
- In the terminal, run `setup.sh`.
- In the terminal, run `run.sh`.
- Use a web browser to navigate to `http://localhost`.

## Providing Feedback and Reporting Issues

We welcome feedback on the tests, including but not limited to the following areas:
- Validation logic, such as potential bugs, lax checks, and unexpected failures.
- Requirements coverage, such as requirements that have been missed and tests
  that necessitate features that the IG does not require.
- User experience, such as confusing or missing information in the test UI.

Please report any problems with these tests in Github Issues. The team may also
be reached in the [#inferno Zulip
stream](https://chat.fhir.org/#narrow/stream/179309-inferno).

## License

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at
```
http://www.apache.org/licenses/LICENSE-2.0
```
Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.

## Trademark Notice

HL7, FHIR and the FHIR [FLAME DESIGN] are the registered trademarks of Health
Level Seven International and their use does not constitute endorsement by HL7.
