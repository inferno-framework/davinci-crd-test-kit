# Da Vinci Coverage Requirements Discovery (CRD) Test Kit

The **Da Vinci Coverage Requirements Discovery (CRD) STU 2.0.1 Test Kit** validates the 
conformance of systems to the [CRD STU 2.0.1 FHIR IG](https://hl7.org/fhir/us/davinci-crd/STU2/index.html).
For additional details on the tests, including their scope, limitations, and status, see the 
[Overview](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Overview)
on the [wiki](https://github.com/inferno-framework/davinci-crd-test-kit/wiki).

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
PostgreSQL](https://inferno-framework.github.io/docs/deployment/database.html#postgresql-with-docker)
to ensure stability in this type of environment.

## Providing Feedback and Reporting Issues

We welcome feedback on the tests, including but not limited to the following areas:
- Validation logic, such as potential bugs, lax checks, and unexpected failures.
- Requirements coverage, such as requirements that have been missed and tests
  that necessitate features that the IG does not require.
- User experience, such as confusing or missing information in the test UI.

Please report any problems with these tests in [issues section](https://github.com/inferno-framework/davinci-crd-test-kit/issues)
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
