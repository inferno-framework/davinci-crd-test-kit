require_relative 'server_tests/external_reference_card_across_hooks_validation_test'
require_relative 'server_tests/instructions_card_received_across_hooks_test'
require_relative 'server_tests/coverage_information_system_action_across_hooks_validation_test'

module DaVinciCRDTestKit
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
    id :crd_server_required_card_response_validation
    run_as_group

    test from: :crd_external_reference_card_across_hooks_validation
    test from: :crd_valid_instructions_card_received_across_hooks
    test from: :crd_coverage_info_system_action_across_hooks_validation
  end
end
