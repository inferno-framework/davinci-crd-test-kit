require_relative 'must_support/client_card_must_support_coverage_information_test'
require_relative 'must_support/client_location_address_propagation_test'
require_relative 'must_support/client_fhirpath_collection_as_comma_delimited_string_test'

module DaVinciCRDTestKit
  module V221
    class ClientCrossHookGroup < Inferno::TestGroup
      title 'Cross Hook Verification'
      id :crd_v221_client_cross_hook
      description <<~DESCRIPTION
        This group checks CRD requirements that pertain across all hooks
        rather than a specific one.

        These tests must be run after the tests in the Hooks group are run.
      DESCRIPTION

      run_as_group

      test from: :crd_v221_client_card_must_support_coverage_information
      test from: :crd_v221_client_location_address_propagation
      test from: :crd_v221_client_fhir_path_collection_as_comma_delimited_string
    end
  end
end
