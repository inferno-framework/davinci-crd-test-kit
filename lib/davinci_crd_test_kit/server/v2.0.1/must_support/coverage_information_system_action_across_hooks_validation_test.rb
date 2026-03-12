require_relative '../test_helper'

module DaVinciCRDTestKit
  class CoverageInformationSystemActionAcrossHooksValidationTest < Inferno::Test
    include DaVinciCRDTestKit::TestHelper

    title 'Valid Coverage Information system actions received across all hooks'
    id :crd_coverage_info_system_action_across_hooks_validation
    description %(
      This test verifies the presence of valid [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information)
      system action returned by CRD services across all hooks invoked. It verifies the following for each action:
      - The action type is `update`.
      - The resource within the action conforms its respective FHIR profile.

      Additionally, the test examines the `coverage-info` extensions within the resource to ensure that:
      - Entries referencing differing coverage have distinct `coverage-assertion-ids` and `satisfied-pa-ids`
      (if present).
      - Entries referencing the same coverage have the same `coverage-assertion-ids` and `satisfied-pa-ids`
      (if present).

      The test will be skipped if no valid Coverage Information system actions are returned across all hooks.
    )

    run do
      verify_at_least_one_test_passes(
        self.class.parent.parent.groups,
        'crd_coverage_info_system_action_validation',
        'None of the hooks invoked returned valid Coverage Info system actions.'
      )
    end
  end
end
