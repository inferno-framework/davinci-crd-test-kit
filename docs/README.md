# Da Vinci CRD Test Kit Documentation

The **Da Vinci Coverage Requirements Discovery (CRD) Test Kit** is a testing tool
that is designed to help implementers validate systems against the 
HL7® FHIR® [Da Vinci Coverage Requirements Discovery Implementation
Guide](https://hl7.org/fhir/us/davinci-crd/). Currently, it includes
suites that verify the behavior of CRD clients and CRD servers
against the following versions of the CRD IG
- [v2.0.1](https://hl7.org/fhir/us/davinci-crd/STU2)
- [v2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1)

The following documentation provides information on how to use and contribute
to this test kit.

## Using this Test Kit

*   **[Getting Started](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/README.md#getting-started)**: Instructions on how to set up and run the test kit.
*   **[Test Kit Overview](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Overview)**: A detailed explanation of what the test kit does, its scope, and how its tests are structured.

### Using the Da Vinci CRD Client Test Suites
*   **[Client Testing Details](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details)**: Description of the client tests.
*   **Client Testing Instructions**: Step-by-step guide for testing client systems, including demonstration executions for both
    the [v2.0.1 version](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Instructions)
    and the [v2.2.1 version](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Instructions-v2.2.1)
*   **[Controlling Simulated CRD server Responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses)**: Details on how testers can control the responses returned by Inferno's simulated CRD server during client testing.

### Using the Da Vinci CRD Server Test Suites 
*   **[Server Testing Details](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Server-Details)**: Description of the server tests.
*   **Server Testing Instructions**: Step-by-step guide for testing server systems, including demonstration executions for both
    the [v2.0.1 version](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Server-Instructions)
    and the [v2.2.1 version](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Server-Instructions-v2.2.1)

## Contributing to this Test Kit

*   **[Technical Overview](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Technical-Overview)**: An overview of the test kit's technical design and architecture for developers and contributors.
*   **[Running the Client and Server Suites Against Each Other](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Running-Suites-Against-Each-Other)**:
    Step-by-step guide for using the client and server suites to demonstrate the test execution without a separate CRD
    implementation, which can be useful for learning as well as debugging.

## Reference Documents

*   **CRD Requirements Spreadsheets**: Spreadsheets detailing the interpretation of CRD IG requirements for this test kit:
    [v2.0.1](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/hl7.fhir.us.davinci-crd_2.0.1_requirements.xlsx)
    and [v2.2.1](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/hl7.fhir.us.davinci-crd_2.2.1_requirements.xlsx).
*   **CDS Hooks Requirements Spreadsheets**: Spreadsheets detailing the interpretation of CDS Hooks specification requirements for this test kit:
    [v2.0 for CRD v2.0.1](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/cds-hooks_2.0_requirements.xlsx)
    and [v3.0.0-ballot for CRD v2.2.1](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/cds-hooks_3.0.0-ballot_requirements.xlsx).
    Note: Although the CRD v2.2.1
    [CDS Hooks background section](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/background.html#cds-hooks)
    references "CDS Hooks 2.0", the IG declares and links to CDS Hooks 3.0.0-ballot;
    this test kit treats CDS Hooks 3.0.0-ballot as the applicable reference for CRD v2.2.1.
*   **[CDS Hooks Library Requirements Spreadsheet](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/cds-hooks-library_1.0.1_requirements.xlsx)**: Spreadsheet detailing the interpretation of hook definnition requirements for this test kit.

## Support

If you have any problems, please open an issue on our [GitHub Issues page](https://github.com/inferno-framework/davinci-crd-test-kit/issues).
