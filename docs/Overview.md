# Da Vinci CRD Test Kit Overview

The **Da Vinci Coverage Requirements Discovery (CRD) Test Kit** is a testing tool designed
to validate the conformance of CRD client and server systems to versions of the
Da Vinci Coverage Requirements Discovery (CRD) FHIR Implementation Guide (IG), including
- [Da Vinci Coverage Requirements Discovery (CRD) STU 2.0.1](https://hl7.org/fhir/us/davinci-crd/STU2), and
- [Da Vinci Coverage Requirements Discovery (CRD) STU 2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1)

This document provides a high-level overview of the Test Kit, including its purpose, general testing
approach, scope, limitations, and guidance on how to interpret results.

## Purpose

This test kit helps implementers ensure that their systems can correctly participate in
coverage requirement discovery workflows as defined by the CRD IG. It does so by simulating
an exchange partner for the system under test (when testing a CRD client Inferno will simulate
a CRD server and vice-versa) and verifying that each exchange is conformant and that
all exchanges in aggregate demonstrate the required capabilities.

This test kit is [open source](#license) and freely available for use or
adoption by the health IT community including EHR vendors, payer systems, health app
developers, and testing labs. It is built using the [Inferno
Framework](https://inferno-framework.github.io/). The Inferno Framework is
designed for reuse and aims to make it easier to build test kits for any
FHIR-based data exchange.

## Test Kit Structure

The CRD Test Kit contains test suites to test the two actors defined by the CRD specification:
- CRD clients: Clients are responsible for initiating CDS Hooks calls and consuming
  received decision support. They are also responsible for returning data requested by the CRD server
  needed to provide that decision support. This role is played by provider systems
  in which orders are placed, such as EHRs. See the [Client Details](Client-Details.md) page
  for more information.
- CRD servers: Servers are responsible for responding to CDS Hooks calls and responding with appropriate
  decision support, which may involve using FHIR requests to gather more data from
  the client. See the [Server Details](Server-Details.md) page for more information.

In each case, content provided by the system under test will be checked individually
for conformance and in aggregate to determine that the full set of features 
required by the IG for the actor is supported.

## General Testing Approach

The test kit validates systems through:

1. **Hook Workflow Simulation**: Tests guide the tested system through CRD hook workflows for each supported hook, including:
   * Invocation of the hook, including authentication via JWT
   * Resource gathering via prefetch and the FHIR API
   * Generation of the hook response
   * Handling of the hook response

2. **FHIR API Access**:
   * Validation of required FHIR APIs outside of a hook invocation

## Test Scope and Limitations

These tests are a **DRAFT** intended to allow CRD implementers to perform
preliminary checks of their implementations against the CRD IG requirements and
provide feedback on the tests. Future versions of these tests may validate other
requirements and may change how these are tested.

While these tests cover core aspects of the CRD IG, there are known limitations:
- Much of what the CRD IG specifies is optional, such as which hooks and resource
  types to support. These tests try to provide testers with an opportunity to
  exercise as much of their systems as they wish and validate that the exercised
  behaviors are correct. However, some areas of the IG may not be exercised.
- CRD workflows involve complex coordination between providers and payers around
  patients, orders, coverages, and other details. Inferno cannot know
  what entities are available in the system it is interacting with or what kinds
  of requests or responses will elicit specific behavior. It also does not want to
  dictate to the systems being tested the specifics of its data, configuration, or
  business rules. For these reasons, testers need to provide Inferno with
  details the requests to make or responses to use.

For a details on specific specific limitations, detailed requirements, and known
issues, please consult the following resources: 
- [Client Testing Limitations](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#testing-limitations)
- [Server Testing Limitations](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Server-Details#testing-limitations)
- Relevant [requirements](https://inferno-framework.github.io/docs/advanced-test-features/requirements.html)
  including those in the
  - CRD Requirements Spreadsheets
    - [v2.0.1](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/hl7.fhir.us.davinci-crd_2.0.1_requirements.xlsx)
    - [v2.2.1](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/hl7.fhir.us.davinci-crd_2.2.1_requirements.xlsx)
  - CDS Hooks Requirements Spreadsheets
    - [v2.0 for CRD v2.0.1](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/cds-hooks_2.0_requirements.xlsx)
    - [v3.0.0-ballot for CRD v2.2.1](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/cds-hooks_3.0.0-ballot_requirements.xlsx)
    - Note: Although the CRD v2.2.1 [CDS Hooks background section](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/background.html#cds-hooks) references "CDS Hooks 2.0", the IG declares and links to CDS Hooks 3.0.0-ballot; this test kit treats CDS Hooks 3.0.0-ballot as the applicable reference for CRD v2.2.1.
  - [CDS Hooks Library Requirements Spreadsheet](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/cds-hooks-library_1.0.1_requirements.xlsx)
- [CRD Test Kit GitHub Issues page](https://github.com/inferno-framework/davinci-crd-test-kit/issues).

## Conformance Criteria & Interpreting Results

A test run is considered successful if all mandatory tests pass:
* **Passing Tests**: Indicate expected behavior for specific scenarios
* **Failing Tests**: Indicate deviations from CRD IG requirements
* **Warnings**: Highlight potential concerns that require manual review
* **Skipped Tests**: Occur when prerequisites are not met

Given the [known limitations](#test-scope-and-limitations), passing all automated tests does **not**
solely constitute full CRD IG conformance. Systems should also meet requirements verified through
attestation or other means.

For specific testing prerequisites and detailed test descriptions, refer to:
* [Client v2.0.1 Suite Testing Instructions](Client-Instructions.md)
* [Client v2.2.1 Suite Testing Instructions](Client-Instructions-v2.2.1.md)
* [Server v2.0.1 Suite Testing Instructions](Server-Instructions.md)
* [Server v2.2.1 Suite Testing Instructions](Server-Instructions-v2.2.1.md)
