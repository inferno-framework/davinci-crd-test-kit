# Da Vinci CRD Test Kit Documentation

The **Da Vinci Coverage Requirements Discovery (CRD) Test Kit** is a testing tool
that is designed to help implementers validate systems against the STU2
version of the HL7® FHIR® [Da Vinci Coverage Requirements Discovery Implementation
Guide](https://hl7.org/fhir/us/davinci-crd/STU2/). The following documentation
provides information on how to use and contribute to this test kit.

## Using this Test Kit

*   **[Getting Started](../tree/main/README.md#getting-started)**: Instructions on how to set up and run the test kit.
*   **[Test Kit Overview](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Overview)**: A detailed explanation of what the test kit does, its scope, and how its tests are structured.

### Using the CRD Client Test Suite
*   **[Client Testing Walkthrough](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Walkthrough)**: Step-by-step guide for testing client systems.
*   **[Controlling Simulated CRD Service Responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses)**: Details on how testers can control the responses provided Inferno's simulated CRD Service during client testing.

### Using the CRD Server Test Suite 
*   **[Server Testing Walkthrough](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Server-Walkthrough)**: Step-by-step guide for testing server systems.

## Contributing to this Test Kit

*   **[Technical Overview](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Technical-Overview)**: An overview of the test kit's technical design and architecture for developers and contributors.
*   **[Server Test Generation Guide](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Test-Generation-Guide)**: Information on how server tests are generated and how to maintain this process.
*   **[Running the Client and Server Suites Against Each Other](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Running-Suites-Against-Each-Other)**: Step-by-step guide for using the Client and Server suites to demonstrate the test execution without a separate CRD implementation, which can be useful
for demonstration as well as debugging.

## Reference Documents

*   **[CRD Requirements Spreadsheet](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/hl7.fhir.us.davinci-crd_2.0.1_requirements.xlsx)**: Spreadsheet detailing the interpretation of CRD IG requirements for this test kit.
*   **[CDS Hooks Requirements Spreadsheet](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/cds-hooks_2.0_requirements.xlsx)**: Spreadsheet detailing the interpretation of CDS Hooks specification requirements for this test kit.
*   **[CDS Hooks Library Requirements Spreadsheet](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/cds-hooks-library_1.0.1_requirements.xlsx)**: Spreadsheet detailing the interpretation of hook definnition requirements for this test kit.

## Support

If you have any problems, please open an issue on our [GitHub Issues page](https://github.com/inferno-framework/davinci-crd-test-kit/issues).
