require_relative 'must_support/coverage_information_system_action_across_hooks_validation_test'
require_relative 'must_support/coverage_information_must_support_test'
require_relative 'verify_response/verify_response_without_billing_options_test'
require_relative 'must_support/supported_us_core_versions_test'
require_relative 'verify_response/verify_response_without_configuration_test'
require_relative 'verify_request/service_request_no_custom_extensions_test'

module DaVinciCRDTestKit
  module V221
    class ServerRequiredCardResponseValidationGroup < Inferno::TestGroup
      title 'Cross-Hook Response Validation'
      description %(
        This group contains tests to verify the behavior of the server responses
        across all hooks.
      )
      # verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@247', 'hl7.fhir.us.davinci-crd_2.0.1@248',
      #                       'hl7.fhir.us.davinci-crd_2.0.1@249'

      id :crd_v221_server_required_card_response_validation
      run_as_group

      test from: :crd_v221_coverage_info_system_action_across_hooks_validation
      test from: :crd_v221_coverage_information_must_support
      test from: :verify_response_without_billing_options
      test from: :verify_response_without_configuration
      test from: :crd_v221_supported_us_core_versions
      test from: :crd_v221_service_request_no_custom_extensions
    end
  end
end
