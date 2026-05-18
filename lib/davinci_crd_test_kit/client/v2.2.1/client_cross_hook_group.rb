require_relative 'cross_hook/client_card_must_support_coverage_information_test'
require_relative 'cross_hook/client_location_address_propagation_test'
require_relative 'cross_hook/client_fhirpath_collection_as_comma_delimited_string_test'
require_relative 'cross_hook/client_hook_instances_unique_test'
require_relative 'cross_hook/client_prefetch_complete_and_subset_test'

module DaVinciCRDTestKit
  module V221
    class ClientCrossHookGroup < Inferno::TestGroup
      title 'Cross Hook'
      id :crd_v221_client_cross_hook
      description <<~DESCRIPTION
        This group checks CRD requirements that pertain across all hooks
        rather than a specific one.

        These tests must be run after the tests in the "Hooks" group are run.
      DESCRIPTION

      run_as_group

      test from: :crd_v221_client_card_must_support_coverage_information
      test from: :crd_v221_client_location_address_propagation
      test from: :crd_v221_client_fhir_path_collection_as_comma_delimited_string
      test from: :crd_v221_client_hook_instances_unique
      test from: :crd_v221_client_prefetch_complete_and_subset
    end
  end
end
