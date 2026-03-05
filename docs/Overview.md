# Da Vinci CRD Test Kit Overview

The **Da Vinci Coverage Requirements Discovery (CRD) STU 2.0.1 Test Kit** validates the 
conformance of systems to the 
[Da Vinci Coverage Requirements Discovery (CRD) STU 2.0.1 FHIR IG](https://hl7.org/fhir/us/davinci-crd/STU2/index.html).

This document provides a high-level overview of the Test Kit, including its purpose, general testing
approach, scope, limitations, and guidance on how to interpret results.

## Purpose

The Da Vinci CRD Test Kit is designed to validate the conformance of healthcare IT systems against [version 2.0.1 of the HL7 FHIR Da Vinci Coverage Requirements Discovery (CRD) Implementation Guide (IG)](https://hl7.org/fhir/us/davinci-crd/STU2/). It helps implementers ensure their systems can correctly participate in coverage requirement discovery workflows as defined by the CRD IG.

This test kit is [open source](#license) and freely available for use or
adoption by the health IT community including EHR vendors, payer systems, health app
developers, and testing labs. It is built using the [Inferno
Framework](https://inferno-framework.github.io/). The Inferno Framework is
designed for reuse and aims to make it easier to build test kits for any
FHIR-based data exchange.

## Test Kit Structure

The CRD Test Kit contains test suites to test the two actors defined by the CRD specification:
- [CRD
  Client](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html):
  responsible for initiating CDS Hooks calls and consuming received decision
  support. It is also responsible for returning data requested by the CRD Server
  needed to provide that decision support. This role is played by provider systems
  in which orders are placed, such as EHRs. See the [Client Details](Client-Details.md) page
  for more information.
- [CRD
  Server](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-server.html):
  responsible for responding to CDS Hooks calls and responding with appropriate
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
  behaviors are correct. However, not all areas of the IG are exercised. For example,
  custom hook configuration is not tested.
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
  including those in the [CRD Requirements Spreadsheet](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/hl7.fhir.us.davinci-crd_2.0.1_requirements.xlsx),
  the [CDS Hooks Requirements Spreadsheet](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/cds-hooks_2.0_requirements.xlsx),
  and the [CDS Hooks Library Requirements Spreadsheet](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/cds-hooks-library_1.0.1_requirements.xlsx)
- [CRD Test Kit GitHub Issues page](https://github.com/inferno-framework/davinci-crd-test-kit/issues).

## Conformance Criteria & Interpreting Results

A test run is considered successful if all mandatory tests pass:
* **Passing Tests**: Indicate expected behavior for specific scenarios
* **Failing Tests**: Indicate deviations from CRD IG requirements
* **Warnings**: Highlight potential concerns that require manual review
* **Skipped Tests**: Occur when prerequisites are not met

Given the known limitations, passing all automated tests does **not** solely constitute full CRD IG conformance. Systems should also meet requirements verified through attestation or other means.

For specific testing prerequisites and detailed test descriptions, refer to:
* [Client Instructions](Client-Instructions.md)
* [Server Instructions](Server-Instructions.md)
