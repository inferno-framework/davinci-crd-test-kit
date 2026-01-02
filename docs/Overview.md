# Da Vinci CRD Test Kit Overview

This document provides a high-level overview of the Da Vinci Coverage Requirements Discovery (CRD) Test Kit, its purpose, and general testing approach.

## Purpose

The Da Vinci CRD Test Kit is designed to validate the conformance of healthcare IT systems against [version 2.0.1 of the HL7 FHIR Da Vinci Coverage Requirements Discovery (CRD) Implementation Guide (IG)](https://hl7.org/fhir/us/davinci-crd/STU2/). It helps implementers ensure their systems can correctly participate in coverage requirement discovery workflows as defined by the CRD IG.

The test kit is built using the [Inferno Framework](https://inferno-framework.github.io/), an open-source platform for building FHIR-based test kits.

## Test Kit Structure

The CRD Test Kit includes two main test suites:

* **Server Test Suite**: For systems acting as payers (see [Server Details](Server-Details.md) for more information)
* **Client Test Suite**: For systems acting as providers (see [Client Details](Client-Details.md) for more information)

## General Testing Approach

The test kit validates systems through:

1. **Hook Workflow Simulation**: Tests guide the system through CRD hook workflows for each supported hook, including:
   * Invocation of the hook, including authentication via JWT
   * Resource gathering via prefetch and the FHIR API
   * Generation of the hook response
   * Handling of the hook response

2. **FHIR API Access**:
   * Validation of required FHIR APIs outside of a hook invocation

## Test Scope and Limitations

This test kit is a **DRAFT**. While it covers core aspects of the CRD IG, there are known limitations.

Much of what the CRD IG specifies is optional, such as which hooks and resource
types to support. These tests try to provide testers with an opportunity to
exercise as much of their systems as they wish and validate that the exercised
behaviors are correct. However, not all areas of the IG are exercised. For example,
custom hook configuration is not tested.

CRD workflows involve complex coordination between providers and payers around
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
- Relevant requirements including those in the [CRD Requirements Spreadsheet](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/requirements/hl7.fhir.us.davinci-crd_2.0.1_requirements.xlsx),
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
