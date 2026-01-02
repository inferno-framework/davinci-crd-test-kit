# Da Vinci Coverage Requirements Discovery (CRD) Test Kit

The **Da Vinci Coverage Requirements Discovery (CRD) STU 2.0.1 Test Kit** validates the 
conformance of systems to the [CRD STU 2.0.1 FHIR IG](https://hl7.org/fhir/us/davinci-crd/STU2/index.html).
The test kit includes suites targeting each of the actors from the specification:

It contains test suites to test the two actors defined by the CRD specification:
- [CRD
  Client](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html):
  responsible for initiating CDS Hooks calls and consuming received decision
  support. It is also responsible for returning data requested by the CRD Server
  needed to provide that decision support. This role is played by provider systems
  in which orders are placed, such as EHRs.
- [CRD
  Server](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-server.html):
  responsible for responding to CDS Hooks calls and responding with appropriate
  decision support, which may involve using FHIR requests to gather more data from
  the client.

In each case, content provided by the system under test will be checked individually
for conformance and in aggregate to determine that the full set of features 
required by the IG for the actor is supported.

This test kit is [open source](#license) and freely available for use or
adoption by the health IT community including EHR vendors, payer systems, health app
developers, and testing labs. It is built using the [Inferno
Framework](https://inferno-framework.github.io/). The Inferno Framework is
designed for reuse and aims to make it easier to build test kits for any
FHIR-based data exchange.

For comprehensive documentation, including detailed walkthroughs, overviews, and
technical references, please see the [Da Vinci CRD Test Kit
Documentation](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/).

## Status

These tests are a **DRAFT** intended to allow CRD implementers to perform
preliminary checks of their implementations against the CRD IG requirements and
provide feedback on the tests. Future versions of these tests may validate other
requirements and may change how these are tested.

Additional details on the IG requirements that underlie this test kit can be found in the [Inferno Requirements Tools](https://inferno-framework.github.io/docs/advanced-test-features/requirements.html),
including the following spreadsheets which contain the requirements extracted from the relevant
specifications:
- [CRD Requirements Spreadsheet](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/hl7.fhir.us.davinci-crd_2.0.1_requirements.xlsx): Spreadsheet detailing the interpretation of CRD IG requirements for this test kit.
- [CDS Hooks Requirements Spreadsheet](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/cds-hooks_2.0_requirements.xlsx): Spreadsheet detailing the interpretation of CDS Hooks specification requirements for this test kit.
- [CDS Hooks Library Requirements Spreadsheet](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/cds-hooks-library_1.0.1_requirements.xlsx): Spreadsheet detailing the interpretation of hook definnition requirements for this test kit.

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

TODO: MOVE ME into wiki

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

## Getting Started

ASTP hosts a [public
instance](https://inferno.healthit.gov/test-kits/davinci-crd/) of this test
kit that developers and testers are welcome to use. However, users are
encouraged to download and run this tool locally to allow testing within private
networks and to avoid being affected by downtime of this shared resource.
Please see the [Local Installation
Instructions](#local-installation-instructions) section below for more
information.

Detailed step-by-step instructions for running the tests can be found in our execution guides:
- [Client Testing Instructions](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Instructions)
- [Server Testing Instructions](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Server-Instructions)

Additional information is provided in the [Da Vinci CRD Test Kit documentation](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/).

## Local Installation Instructions

- [Download an official release](https://github.com/inferno-framework/davinci-crd-test-kit/releases) of this test kit.
- Open a terminal in the directory containing the downloaded code.
- In the terminal, run `setup.sh`.
- In the terminal, run `run.sh`.
- Use a web browser to navigate to `http://localhost`.

More information on using Inferno Test Kits is available on the [Inferno
Framework documentation site](https://inferno-framework.github.io/docs).

### Multi-user Installations

The default configuration of this test kit uses SQLite for data persistence and
is optimized for running on a local machine with a single user. For
installations on shared servers that may have multiple tests running
simultaneously, please [configure the installation to use
PostgreSQL](https://inferno-framework.github.io/inferno-core/deployment/database.html#postgresql)
to ensure stability in this type of environment.

## Providing Feedback and Reporting Issues

We welcome feedback on the tests, including but not limited to the following areas:
- Validation logic, such as potential bugs, lax checks, and unexpected failures.
- Requirements coverage, such as requirements that have been missed and tests
  that necessitate features that the IG does not require.
- User experience, such as confusing or missing information in the test UI.

Please report any problems with these tests in [issues section](https://github.com/inferno-framework/da-vinci-crd-test-kit/issues)
of this repository. The team may also be reached in the [#inferno Zulip
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
