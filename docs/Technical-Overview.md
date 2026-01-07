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

The primary codebase for the CRD Test Kit resides within the `lib/davinci_crd_test_kit/` directory. Key subdirectories and files under that include:

* **[`crd_client_suite.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/crd_client_suite.rb)**: Defines the main test suite for CRD clients.
* **[`crd_server_suite.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/crd_server_suite.rb)**: Defines the main test suite for CRD servers.
* **[`metadata.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/metadata.rb)**: Contains metadata for the CRD test kit, including its title, description (which appears in the Inferno UI), and suite IDs. This is a crucial file for how the test kit presents itself in the Inferno Framework.
* **[`version.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/version.rb)**: Specifies the version of the test kit.
* **[`card_responses/`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/card_responses) directory**: contains template responses used when to mock responses in the CRD client tests ([details](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)).
* **[`client_tests/`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/client_tests) directory**: contains the tests and groups used in the client suite.
* **[`ext/`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/ext) directory**: contains an extension of the Inferno base runnable logic to uniformly handle CORS.
* **[`igs/`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/igs) directory**: contains a local copy of the CRD v2.0.1 IG.
* **[`requirements/`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/requirements) directory**: contains extracted CRD and CDS Hooks requirements and related files used by the [Inferno Requirements Tools](https://inferno-framework.github.io/docs/advanced-test-features/requirements.html).
* **[`routes/`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/routes) directory**: contains endpoints and route logic for when Inferno responds to external requests, including discovery and hook endpoints for the client suite's simulated CRD Server and a jwks endpoint for the server suite's simulated CRD client ([jwk set](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/crd_jwks.json)). NOTE: the hook endpoint response generation logic lives at the top-level: [custom_service_response.rb](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/custom_service_response.rb) and [mock_service_response.rb](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/mock_service_response.rb).
* **[`server_tests/`](https://github.com/inferno-framework/davinci-crd-test-kit/tree/main/lib/davinci_crd_test_kit/server_tests) directory**: contains the tests used in the server suite. NOTE: the server groups are defined one directory level up.
* **[`cards_identification.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/cards_identification.rb)**: Defines the logic for identifying the CRD type of a CDS Hook card or system action (e.g., [Instructions](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#instructions) or [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information)).
* Verification Logic: Several files define the logic for verifying the conformance of CDS Hooks requests and responses, including cards to CRD card profiles (e.g., [Instructions](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#instructions) or [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information)). 
  - **[`cards_validation.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/cards_validation.rb)**
  - **[`client_hook_request_validation.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client_hook_request_validation.rb)**
  - **[`hook_request_field_validation.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/hook_request_field_validation.rb)**
  - **[`server_hook_request_validation.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/server_hook_request_validation.rb)**
  - **[`suggestion_actions_validation.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/suggestion_actions_validation.rb)**
* Response Generation Support: Several files define logic that supports custom response creation:
  - **[`fhirpath_on_cds_request.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/fhirpath_on_cds_request.rb)**: Contains logic to execute FHIRPath expression on CDS Hook requests, which is used in the creation of [custom responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses). Note that there are [critical limitations](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#fhirpath-evaluation-limitations).
  - **[`gather_response_generation_data.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/gather_response_generation_data.rb)**: Contains logic to request data from the CRD client, which is used in the creation of [custom responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses) and also to verify data provided via prefetch.
  - **[`replace_tokens.rb`](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/replace_tokens.rb)**: Contains logic to replace [dynamic tokens in custom response templates](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#expression-tokens), which is used in the creation of [custom responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses). Leverages the capability to [execute FHIRPath on CDS Hook requests](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/fhirpath_on_cds_request.rb).

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
*   **[Da Vinci CRD Implementation Guide](https://hl7.org/fhir/us/davinci-crd/STU2/)**: The specific set of rules and profiles this test kit validates against.
*   **[CDS Hooks Implementation Guide](https://cds-hooks.hl7.org/STU2/)**: The underlying framework for integrating decision support into clinical workflows.
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
6.  **Update Documentation**: If your changes affect user-facing behavior, test procedures, or technical details, update the relevant documentation files in `/docs/`. These will be automatically mirrored to the repository's [GitHub Wiki](https://github.com/inferno-framework/davinci-pas-test-kit/wiki).

## Contribution Guidelines

*   **Follow Existing Patterns**: Try to adhere to the coding style and architectural patterns already present in the test kit and the Inferno Framework.
*   **Write RSpec Tests**: For new logic or significant changes, add corresponding RSpec tests.
*   **Keep Documentation Updated**: Ensure your contributions are reflected in the documentation.
*   **Report Issues**: Use the [GitHub Issues page](https://github.com/inferno-framework/davinci-pas-test-kit/issues) for the repository to report bugs or suggest enhancements.
*   **Pull Requests**: Submit changes via pull requests for review.
*   **Update Documentation**: Please be sure to update all suite descriptions, test descriptions, the README, and the contents of the `./docs` folder of this repository along with code changes.

## Unusual Implementation Details

*   **Test Data Input**: For client and server testing, the kit relies heavily on users providing their own conformant responses or requests that are designed to elicit specific behavior within the tested system. This avoids artificial requirements where the tested system must be configured with Inferno-specific details not present in the CRD or underlying specifications.
