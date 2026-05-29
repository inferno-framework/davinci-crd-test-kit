# Da Vinci CRD Test Kit: Technical Overview

This document provides a technical overview of the Da Vinci Coverage Requirements Discovery (CRD) Test Kit, aimed at developers and contributors. It covers test design principles, code organization, related systems, and guidelines for testing code changes.

## Test Design Principles

The CRD Test Kit is built upon the Inferno Framework and adheres to its core design principles:

*   **FHIR-Native**: Tests are designed around FHIR interactions and data models.
*   **IG-Centric**: Validation is based on the requirements and profiles defined in the Da Vinci CRD Implementation Guide and the CDS Hooks specifications that it builds on.
*   **Actor-Based Testing**: Separate test suites target client and server actors, simulating the counterpart system.
*   **Automated Validation**: Wherever possible, conformance is checked automatically. This includes FHIR resource validation, profile conformance, and workflow logic.
*   **Transparency**: Test logic and results are intended to be clear and understandable, aiding implementers in identifying issues.
*   **Extensibility**: The Inferno Framework allows for the creation of custom tests and test suites.

## Code Organization

The primary codebase for the CRD Test Kit resides within the [`lib/davinci_crd_test_kit/`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/)
directory. Key subdirectories and files under that include:

* **[`client`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/client) directory**:
  contains code related to the client actor test suites.
* **[`cross_suite`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/cross_suite) directory**:
  contains code that is shared or is intended to be shared between client and server suites.
* **[`server`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/server) directory**:
  contains code related to the server actor test suites.

Files that control the display of the test kit itself within an inferno platform deployment include
* **[`metadata.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/metadata.rb)**: Contains metadata for the CRD test kit, including its title, description (which appears in the Inferno UI), and suite IDs. This is a crucial file for how the test kit presents itself in the Inferno Framework.
* **[`version.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/version.rb)**: Specifies the version of the test kit.
* **[`requirements/`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/requirements) directory**: contains extracted CRD and CDS Hooks requirements and related files used by the [Inferno Requirements Tools](https://inferno-framework.github.io/docs/advanced-test-features/requirements.html).

### Actor-specific Organization and Key Files

Within the `client` and `server` actor directories, files are generally organized as follows
* directories corresponding to specific versions, e.g., [`client/v2.2.1`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/client/v2.2.1),
  contain the suite, group, and test definitions for the suite corresponding to that version. They contain
  one level of sub-folders corresponding to different functional areas.
* code shared across versions lives directly within the actor directories and in other sub folders. This
  includes both shared verification logic
  as well as actor simulations, e.g., for the client suites helper modules like [tagged_request_load_helper.rb](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/tagged_request_load_helper.rb)
  and the endpoints simulating a CRD server in [`client/endpoints`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/client/endpoints).

#### Key Client Components

- [**CDS service simulation code**](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/client/endpoints):
  Logic for responding to CDS Hooks Invocation is shared across all client suites and includes the following files:
  - [*`cds_services_discovery_handler.rb`*](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/endpoints/cds_services_discovery_handler.rb):
    Serves the discovery responses by finding the corresponding file under the version-specific directory.
  - [*`hook_request_endpoint.rb`*](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/endpoints/hook_request_endpoint.rb):
    Primary Inferno [Suite Endpoint](https://inferno-framework.github.io/docs/advanced-test-features/waiting-for-requests.html#advanced-incoming-request-handling)
    definition used for all hooks. Responsible for finding the session, building the response, and storing it in the database tagged for
    later use during evaluation.
  - [*`gather_response_generation_data.rb`*](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/endpoints/gather_response_generation_data.rb):
    Used by `hook_request_endpoint.rb` to make FHIR requests against the invoking client's FHIR APIs. The scope of these requests is
    different for [v2.0.1](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#data-fetching-during-hook-invocations) and [v2.2.1](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#prefetch-and-additional-data-retrieval).
  - [*`mock_service_response.rb`*](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/endpoints/mock_service_response.rb):
    Used by *hook_request_endpoint.rb* to create simple mocked hook responses based on types selected when running the tests. Templates
    for the responses live in the [`mocked_card_responses` subdirectory](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/client/endpoints/mocked_card_responses)
  [*`custom_service_response.rb`*](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/endpoints/mock_service_response.rb):
    used by *hook_request_endpoint.rb* to generate [custom responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses) based on a tester-provided template specified when running the tests.
- [**`crd_client_options.rb`**](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/crd_client_options.rb):
  Inferno [suite option](https://inferno-framework.github.io/docs/advanced-test-features/test-configuration.html#suite-options)
  constants used across all client suites.
- [**`tagged_request_load_helper.rb`**](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/tagged_request_load_helper.rb):
  A utility module design to help load request messages tagged by the simulated CRD server endpoints. Many tests load these
  requests to evaluate them and their responses so this module reduces code duplication significantly. It contains options
  for loading requests related to a specific hook or all hooks.
- [**`multi_request_message_helper.rb`**](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/multi_request_message_helper.rb):
  A utility module for logging errors and warnings on tests that evaluate multiple requests. Adds prefixes so that testers
  can identify which request triggered the issue. Also identifies which requests had errors so that they can be identified
  in the top-level result message.

#### Key Server Components

- [**FHIR server simulation code**](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/server/endpoints/mock_ehr):
  Defines logic implementing a simple FHIR server that supports read, search, create, update, and delete interactions
  by accessing and manipulating a FHIR Bundle stored within an Inferno input tied to a specific session. This allows the tester
  to control the data hosted on the server. The search implementation is the most complex and re-uses the US Core Test Kit's logic
  to check the results returned in searches. The implementation is still relatively new. Based on the data structure, it is not
  expected to scale to large numbers of resources, but it successfully served the [Inferno Reference Server data](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/server/endpoints/mock_ehr/stress-test-Bundle.json)
  used to verify the (g)(10) test kit behavior at least as fast as the Inferno Reference Server itself.
- [**JSON Web Key Set hosting**](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/server/endpoints):
  Within the `server/endpoints` directory are several files that handle the publication of a jwks that the Inferno's simulated CRD
  client will use to identify itself and sign JWTs on hook invocations made as a part of the server tests.
- [**Hook invocation job**](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/server/jobs/invoke_hook.rb):
  In order to support the simulated FHIR server based on a Bundle in a session input and make it active during hook invocations made by
  Inferno's simulated CRD client, these hook invocations must be made during a wait test. Invocation tests spawn instances of this job
  which runs and performs the hook invocations while Inferno is waiting. The job either triggers the continuation of the tests once
  complete or waits for tester input depending on the inputs provided by the tester.
- [**`server_hook_helper.rb`**](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/server/server_hook_helper.rb):
  A utility module for helping to identify hooks to invoke and load requests to analyze.

### `cross_suite` Organization and Key Files

Key shared logic within the [`cross_suite`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/cross_suite)
directory includes:
* **[`base_urls.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/cross_suite/base_urls.rb)**:
  defines urls used by suites for both client and server actors, such as pass and fail continuation urls displayed in wait dialogs.
* **[`profiles_and_resource_types.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/cross_suite/profiles_and_resource_types.rb)**: contains constants and methods related to CRD allowed resource types and profiles used in many places
  within the code base.
  defines urls used by suites for both client and server actors, such as pass and fail continuation urls displayed in wait dialogs.
* **[`cards_identification.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/cross_suite/cards_identification.rb)**: Defines the logic for identifying the CRD type of a CDS Hook card or system action (e.g., [Instructions](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#instructions) or [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information)).
* **Manual Verification Logic**: Several files define logic for verifying the conformance of CDS Hooks requests and responses,
  including cards to CRD card profiles (e.g., [Instructions](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#instructions)
  or [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information)). Starting with the v2.2.1
  version, the CRD IG publishes logical models which can be used by the HL7 FHIR validator to verify. However, the published models
  are incomplete and contain some inconsistencies that mean these hand-created versions are still in use.
  - **[`cards_validation.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/cross_suite/cards_validation.rb)**
  - **[`hook_request_field_validation.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/cross_suite/hook_request_field_validation.rb)**
  - **[`suggestion_actions_validation.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/cross_suite/suggestion_actions_validation.rb)**
* **Logical Model-based Verification Logic**: Logical models describing CRD requests and responses are new as of the [2.2.1 version of the IG](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/artifacts.html#structures-logical-models).
  Shared modules for performing validation against these models that attempt to correct for gaps and bugs in them are available:
  - **[`response_logical_model_validation.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/cross_suite/response_logical_model_validation.rb)**:
    Card logical models in the 2.2.1 version require some response mangling to get to work, which is handled by this module.
  - **[`requests_logical_model_validation.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/cross_suite/requests_logical_model_validation.rb)**: Unlike card models, request models can be used directly.
  - **[`logical_models_override_helper.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/cross_suite/logical_models_override_helper.rb)**: Contains helper functions designed to correctly verify conformance of CRD requests
    and responses in situations where the logical models are incorrect, don't work correctly with the HL7 validator, or the HL7
    validator's responses lack necessary detail. For example, CRD Appointment profile validation requires some additional help outside
    the validator due to profile-based slicing that the validator won't evaluate without additional setup.
* **Prefetch Verification Logic**: because prefetch details are defined by the CRD server, the logical models introduced starting in CRD v2.2.1
  do not verify prefetch details provided in CRD requests. Furthermore, the requirements evolved significantly from v2.0.1, meaning that there
  are several modules assisting with prefetch verification:
  - **[`prefetch_contents_validation.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/cross_suite/prefetch_contents_validation.rb)**: Used to check v2.0.1 prefetch fields for validity. In that version support for prefetch is optional.
  - **[`prefetch_completeness_checker.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/cross_suite/prefetch_completeness_checker.rb)**:
    In the 2.2.1 version, prefetch support is required including standard prefetch templates that payers can use and expect
    the corresponding data. This module checks the prefetch field of a request against a prefetch definition
    from a discovery response.
  - **[`prefetch_profile_validation.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/cross_suite/prefetch_profile_validation.rb)**:
    Checks that the resources provided under the prefetch field conform to the associated CRD profiles.
* **FHIRPath Support**: Prefetch checking and custom response generation leverage FHIRPath executed on CDS Hooks requests.
  The FHIRPath module that Inferno uses does not support execution on general json objects like CDS Hooks requests
  or handle functions like `resolve()`. A wrapper is provided to support these capabilities for use in the test kit, including:
  - **[`fhirpath_on_cds_request.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/fhirpath_on_cds_request.rb)**: Contains logic to execute FHIRPath expression on CDS Hook requests. Note that there
  are [critical limitations](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#fhirpath-evaluation-limitations).
  - **[`replace_tokens.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/replace_tokens.rb)**: Contains logic to replace [dynamic tokens in custom response templates](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#expression-tokens), which is used in the creation of [custom responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses)
  as well as when evaluating prefetch templates.

### Additional Files and Directories

At the top level of this repository are some additional files and directories of note:
*   **[`config/`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/config) Directory**: contains `.conf` configuration files for nginx that help wire test kit components together when run in Docker mode or Ruby-based developer mode.
*   **[`config/presets/`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/config/presets) Directory**: contains `.erb` files used to populate the presets dropdowns for each CRD test suite.
*   **[`docs/`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/docs) Directory**: Contains Markdown documentation files that are mirrored to the [GitHub wiki](/inferno-framework/davinci-crd-test-kit/wiki) for this repository.
*   **[`spec/`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/spec) Directory**: Contains RSpec-based unit tests for the CRD test kit.
*   **`.env*` files**: Contains environment settings. [`.env.production`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/.env.production) is used when run in Docker-mode and [`.env.development`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/.env.development) is used when run in the Ruby-based developer mode.
*   **`docker-componse*.yml` files**: Contains Docker configuration details for us when running in Docker-mode ([`docker-compose.yml`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/docker-compose.yml)) and in Ruby-based developer mode ([`docker-compose.background.yml`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/docker-compose.background.yml)). These files define the services that Inferno needs to run, such as the FHIR Validator and nginx.

## Related Systems and Dependencies

*   **[Inferno Framework](https://inferno-framework.github.io/)**: The foundational platform upon which this test kit is built. Knowledge of Inferno's architecture and development patterns is essential for significant contributions.
*   **[HL7 FHIR R4](https://hl7.org/fhir/R4/index.html)**: The core standard for data exchange.
*   **[Da Vinci CRD Implementation Guide](https://hl7.org/fhir/us/davinci-crd/)**: The specific set of rules and profiles this test kit validates against. This test kit contains suites that target two versions of the IG:
    - [v2.0.1](https://hl7.org/fhir/us/davinci-crd/STU2)
    - [v2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1)
*   **[CDS Hooks Implementation Guide](https://cds-hooks.hl7.org)**: The underlying framework for integrating decision support into clinical workflows. Each CRD IG version uses a specific CDS Hooks version:
    - [CRD v2.0.1](https://hl7.org/fhir/us/davinci-crd/STU2) uses [CDS Hooks v2.0.1](https://cds-hooks.hl7.org/STU2/)
    - [CRD v2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1) uses [CDS Hooks v3.0.0-ballot](https://cds-hooks.hl7.org/2026Jan)
*   **[FHIR Java Validator](https://confluence.hl7.org/spaces/FHIR/pages/35718580/Using+the+FHIR+Validator)**: Used for validating resource conformance.
*   **Terminology Server ([`tx.fhir.org`](https://tx.fhir.org/))**: Used by the validator to resolve terminology and validate code bindings.
*   **[Ruby](https://www.ruby-lang.org/en/)**: The programming language used for Inferno and this test kit.
*   **[RSpec](https://rspec.info/)**: The testing framework used for the test kit's own internal unit/integration tests (see the [`spec/`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/spec) directory).

## Testing Code Changes (Development Workflow)

When making changes to the test kit itself, it's important to ensure the changes are correct and do not introduce regressions.

1.  **Understand the Scope**: Determine if your change affects generated tests, custom test groups, core logic, or documentation.
2.  **Make Code Changes**: Implement your fixes or new features.
3.  **Run RSpec Tests**:
    *   The test kit has its own suite of tests located in the `spec/` directory. These are RSpec tests that validate the test kit's internal logic, generators, etc.
    *   From the root directory of the test kit, you can typically run these tests using a command like `bundle exec rspec`.
    *   Ensure all RSpec tests pass before considering your changes complete.
4.  **Manual Testing (Using Inferno UI)**:
    *   Run your local Inferno instance (`run.sh` after `setup.sh`), or use the [developer-oriented method](https://inferno-framework.github.io/docs/getting-started/#development-with-ruby).
    *   Manually execute the test suites/groups affected by your changes against:
        *   The public reference implementations (if applicable).
        *   Any local test servers or client simulators you have.
        *   The provided Postman collection for client tests.
    *   This helps catch issues that RSpec tests might miss, especially those related to UI interactions or workflow logic as experienced by a user.
6.  **Update Documentation**: If your changes affect user-facing behavior, test procedures, or technical details,
    update the relevant documentation files in `/docs/`. These will be automatically mirrored to the repository's
    [GitHub Wiki](https://github.com/inferno-framework/davinci-crd-test-kit/wiki).

## Naming and Style Guidelines

Consistency in naming and documentation helps to make the test kit and its suites clear
and understandable to users. The maintainers of this repository strongly recommend following
the naming and style guidelines in this section. See the "Da Vinci CRD Client v2.2.1 Test Suite"
for an example a suite that follows these guidelines. Other suites in this test kit may not
currently follow these guidelines.

### Suite, Group, and Test Titles

- **Capitalization scheme**
  - *Suites* and *Groups*: Capitalize each word of the title of suites and groups.
  - *Tests*: Capitalize only the first word of test titles.
  - *Exceptions*: Formal entities from the specifications with specific capitalization schemes,
    e.g., hook names like `appointment-book` are never capitalized and formal response types
    defined in the CRD guide like "Coverage Information" are always capitalized.
- Naming scheme
  - *Suites*: For suite titles, use the form "<IG> <Actor> <Version> Test Suite",
    e.g., "Da Vinci CRD Client v2.2.1 Test Suite".
  - *Groups*: For group titles, use a short noun or noun phrase representing what
    is being checked within the group, e.g., "Registration", "order-sign", or
    "Response Handling".
  - *Tests*: The form of test titles depends on the type of test
    - Verification tests (most): For tests that verify behavior, use the form 
      "<Subject> <criteria checked>", e.g., "Client made additional FHIR data available
      during hook request processing" and "Prefetched resources conform to the required
      CRD profiles".
    - Interaction tests: For tests where the primary activity is an interaction, use the
      form "<Subject> <action>", e.g., "Client invokes the order-sign hook".

### References to Inferno Entiries

- *Suites*, *Groups*, and *Tests*: When referencing an Inferno suite, group, or test,
  put the name in double quotes. Optionally include the short Id as a prefix. For example,
  the following phrases are both acceptable:
  - group "1.1 Registration"
  - the "Registration" group
- *Presets*: When referencing a preset, put the name in double quotes.
- *Inputs*: When referencing an input, **bold** the name.

### Suite, Group, and Test Descriptions

- *Suites*: Suite descriptions should contain brief text with references to additional
details within this wiki. The following important details should be included or
highlighted as available on a linked pagee:
  - Required setup and information needed to run the tests,
  - Instructions for execution including how to populate inputs, ideally both a
    minimal and maximal run, and
  - Details on interpreting the results, including what constitutes a passing session
    and what limitations a pass result has.
- *Groups*: Groups don't necessarily need descriptions. When present, group descriptions
  can provide context, explain how the contained groups/tests are run, and/or
  explain what a passing run looks like.
- *Tests*: Tests must have a description. Test descriptions can provide additional
  context to explain the test and how it works. They must provide a paragraph
  explaining what the test checks (or does, for interaction tests), starting
  with “During this test, Inferno will verify …” for verification tetss and
  “During this test, Inferno will wait for …”

## Contribution Guidelines

We welcome contributions in the form of bug reports or enhancement suggestions as well as implementations
submitted for our review via a pull request.

To report an bug or suggest an enhancement, use the [GitHub Issues page](https://github.com/inferno-framework/davinci-crd-test-kit/issues) for the repository.

When submitting a PR with an update to the code base for us to review, follow these guidelines
to ensure that your update is one that we can commit to reviewing and maintaining:
*   **Follow Existing Patterns**: Try to adhere to the coding style and architectural patterns already present in the test kit and the Inferno Framework.
*   **Write RSpec Tests**: For new logic or significant changes, add corresponding RSpec tests.
*   **Update Presets**: If your changes add inputs, update any relevant presets with values for
    those inputs.
*   **Update Documentation**: Please be sure to update all suite descriptions, test descriptions, the README, and the contents of the `./docs` folder of this repository along with code changes.
*   **Provide Manual Testing Instructions**: In your PR, provide instructions for running the
    tests in a way that demonstrates that the change is working. If a new test or verification
    has been added, include instructions for both a passing and failing example.

## Unusual Implementation Details

*   **Test Data Input**: For client and server testing, the suites in this test kit rely heavily
    on testers providing their own conformant responses or requests that are designed to elicit
    specific behavior within the tested system. This avoids artificial requirements where
    the tested system must be configured with Inferno-specific details not present in the
    CRD or underlying specifications. To ensure that Inferno's use of tester-provided content
    demonstrates conformant exchange, the content is checked against the relevant requirements
    for the actor that Inferno is simulating as a part of testing the exchange (these tests
    are labled as "simulation verification" tests).
