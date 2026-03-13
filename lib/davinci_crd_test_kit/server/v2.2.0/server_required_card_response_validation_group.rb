require_relative 'must_support/external_reference_card_across_hooks_validation_test'
require_relative 'must_support/instructions_card_received_across_hooks_test'
require_relative 'must_support/coverage_information_system_action_across_hooks_validation_test'

module DaVinciCRDTestKit
  module V220
    class ServerRequiredCardResponseValidationGroup < Inferno::TestGroup
      title 'Required Card Response Validation'
      description %(
        This group contains tests to verify the presence and validity of required response types
        across all hooks invoked. As per the [Da Vinci CRD Implementation Guide](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#potential-crd-response-types),
        CRD Servers SHALL, at minimum, demonstrate an ability to return the following response types:
        - Coverage Information System Action
        - External Reference Card
        - Instructions Card
      )
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@247', 'hl7.fhir.us.davinci-crd_2.0.1@248',
                            'hl7.fhir.us.davinci-crd_2.0.1@249'

      id :crd_v220_server_required_card_response_validation
      run_as_group

      test from: :crd_v220_external_reference_card_across_hooks_validation
      test from: :crd_v220_valid_instructions_card_received_across_hooks
      test from: :crd_v220_coverage_info_system_action_across_hooks_validation
    end
  end
end
