require_relative '../../server_test_helper'

module DaVinciCRDTestKit
  module V221
    class CoverageInformationSystemActionAcrossHooksValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper

      title 'Coverage Information system actions are valid across all hooks'
      id :crd_v221_coverage_info_system_action_across_hooks_validation
      description %(
        During this test, Inferno will verify that at least one hook group returned valid
        [Coverage Information](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type)
        system actions.

        The hook-specific Coverage Information validation verifies the following for each action:
        - The action type is `update`.
        - The resource within the action conforms its respective FHIR profile.

        It also examines the `coverage-info` extensions within the resource to ensure that:
        - Entries referencing differing coverage have distinct `coverage-assertion-ids` and `satisfied-pa-ids`
        (if present).
        - Entries referencing the same coverage have the same `coverage-assertion-ids` and `satisfied-pa-ids`
        (if present).

        Inferno skips this test if no valid Coverage Information system actions are returned across all hooks.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-14'

      run do
        verify_at_least_one_test_passes(
          self.class.parent.parent.groups,
          'crd_v221_coverage_info_system_action_validation',
          'None of the hooks invoked returned valid Coverage Information system actions.'
        )
      end
    end
  end
end
