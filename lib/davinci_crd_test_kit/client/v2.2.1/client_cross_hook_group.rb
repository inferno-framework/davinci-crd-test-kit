require_relative 'cross_hook/client_card_must_support_coverage_information_test'
require_relative 'cross_hook/client_location_address_propagation_test'
require_relative 'cross_hook/client_fhirpath_collection_as_comma_delimited_string_test'
require_relative 'cross_hook/client_hook_instances_unique_test'
require_relative 'cross_hook/client_prefetch_complete_and_subset_test'
require_relative 'client_cross_hook_interaction_group'

module DaVinciCRDTestKit
  module V221
    class ClientCrossHookGroup < Inferno::TestGroup
      title 'Cross Hook'
      id :crd_v221_client_cross_hook
      description <<~DESCRIPTION
        This group checks CRD requirements that pertain across all hooks
        rather than a specific one.

        These tests must be run after the tests in the "Hooks" group are run.
        Clients may, but are not required to, make additional hook requests
        during these tests to show additional features not demonstrated during
        previous hook requests.
      DESCRIPTION

      run_as_group

      group from: :crd_v221_client_cross_hook_interaction
      group do
        id :crd_v221_client_cross_hook_must_support
        title 'Must Support'

        test from: :crd_v221_client_card_must_support_coverage_information
      end
      group do
        id :crd_v221_client_cross_hook_additional_capabilities
        title 'Additional Capabilities'

        test from: :crd_v221_client_location_address_propagation
        test from: :crd_v221_client_fhir_path_collection_as_comma_delimited_string
        test from: :crd_v221_client_hook_instances_unique
        test from: :crd_v221_client_prefetch_complete_and_subset
      end
    end
  end
end
