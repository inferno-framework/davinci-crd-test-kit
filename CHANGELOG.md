# 0.12.1
* FI-3838: Add CRD Server verifies_requirements by @elsaperelli in https://github.com/inferno-framework/davinci-crd-test-kit/pull/23
* FI-3837: Add CRD Client verifies_requirements by @elsaperelli in https://github.com/inferno-framework/davinci-crd-test-kit/pull/21
* FI-4055: Client Auth by @karlnaden in https://github.com/inferno-framework/davinci-crd-test-kit/pull/25

# 0.12.0
## Breaking Change
This release updates the Da Vinci CRD Test Kit to use AuthInfo rather than
OAuthCredentials for storing auth information. As a result of this change, any
test kits which rely on this test kit will need to be updated to use AuthInfo
rather than OAuthCredentials inputs.

* FI-3746: Transition to use authinfo by @vanessuniq in https://github.com/inferno-framework/davinci-crd-test-kit/pull/20

# 0.11.1
* FI-3877: Pin CRD IG version to 2.0.1 by @karlnaden in https://github.com/inferno-framework/davinci-crd-test-kit/pull/18

# 0.11.0
* **Inferno Core Update:** Bumped to version `0.6.2`.
* **Ruby Version Update:** Upgraded Ruby to `3.3.6`.
* **TLS Version Update:** Bumped to `0.3.0`.
* **SMART App Launch Version Update:** Bumped to `0.5.0`.
* **Gemspec Updates:**
  * Switched to `git` for specifying files.
  * Added `presets` to the gem package.
  * Updated dependencies to include the new Ruby and Inferno Core versions.
* **Test Kit Metadata:** Implemented test kit metadata.
* **Environment Updates:** Updated Ruby version in the `Dockerfile` and GitHub Actions workflow.
* FI-3648: Add Spec for Shared Tests and Implement Features for the Failing Tests by @vanessuniq in https://github.com/inferno-framework/davinci-crd-test-kit/pull/14
* Fi 3718 hook demonstration test by @karlnaden in https://github.com/inferno-framework/davinci-crd-test-kit/pull/15

# 0.10.0
* FI-3410: Update inferno core requirement by @Jammjammjamm in https://github.com/inferno-framework/davinci-crd-test-kit/pull/11

# 0.9.1
* FI-2785: Make tests for optional features optional by @emichaud998 in https://github.com/inferno-framework/davinci-crd-test-kit/pull/2
* FI-2826: Fix errors produced by testing server and client against one another by @emichaud998 in https://github.com/inferno-framework/davinci-crd-test-kit/pull/3
* FI-2829: Add Optional Coverage Info Check to Hooks Not Requiring It by @vanessuniq in https://github.com/inferno-framework/davinci-crd-test-kit/pull/6
* FI-2768: Client Allow Multiple Requests Per Hook by @emichaud998 in https://github.com/inferno-framework/davinci-crd-test-kit/pull/1
* Dependency Updates 2024-07-03 by @Jammjammjamm in https://github.com/inferno-framework/davinci-crd-test-kit/pull/7
* FI-3055: Allow user provided cds responses by @Jammjammjamm in https://github.com/inferno-framework/davinci-crd-test-kit/pull/8
