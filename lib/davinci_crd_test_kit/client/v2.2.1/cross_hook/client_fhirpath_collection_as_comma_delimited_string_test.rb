module DaVinciCRDTestKit
  module V221
    class ClientFHIRPathCollectionAsCommaDelimitedStringTest < Inferno::Test
      title 'Client correctly interprets collections when substituting FHIRPath results in prefetch templates'
      id :crd_v221_client_fhir_path_collection_as_comma_delimited_string
      description <<~DESCRIPTION
        The CDS Hooks specification requires that when a FHIRPath token in A
        prefetch template resolves to a collection of datatypes (e.g., resource ids),
        then the collection gets turned into a comma-delimited string when instantiating
        the prefetch template.

        During this test, Inferno will verify that during a previously-run hook test,
        there was at least one instance of a prefetch template that has a
        token which Inferno expects to result in a collection with multiple unique members.
        Note that this does not test whether the client correctly
        handles the collection, which is checked by the
        "Hook requests include the requested prefetch data" test.

        This test relies on the evaluation performed by the "Hook requests include the
        requested prefetch data" test present in each hook-specific "Requests" group. One of these groups
        must have been run and resulted in a "Hook requests include the requested prefetch data"
        test that outputs "demonstrates_fhirpath_collection_as_comma_delimited_string" as true.
      DESCRIPTION

      verifies_requirements 'cds-hooks_3.0.0-ballot@239', 'cds-hooks_3.0.0-ballot@242'

      run do
        completeness_tests = find_completeness_tests
        pass_if completeness_tests_demonstrate_collection_token_substitution?(completeness_tests)

        skip 'No prefetch template requiring FHIRPath collection token substitution demonstrated. ' \
             'Perform more complex hook requests and re-run.'
      end

      def find_completeness_tests
        hooks_group = self.class.parent.parent.groups.find do |group|
          group.id.to_s.include?('crd_v221_client_hooks')
        end
        hooks_group.groups.map do |group|
          group.groups.flat_map(&:tests).find do |test|
            test.id.to_s.include?('crd_v221_hook_request_prefetch_complete')
          end
        end.compact
      end

      def completeness_tests_demonstrate_collection_token_substitution?(prefetch_completeness_tests)
        results_repo = Inferno::Repositories::Results.new
        results = results_repo.current_results_for_test_session_and_runnables(test_session_id,
                                                                              prefetch_completeness_tests)

        results.any? do |result|
          result.outputs.any? do |output|
            output['name'] == 'demonstrates_fhirpath_collection_as_comma_delimited_string' &&
              output['value'] == 'true'
          end
        end
      end
    end
  end
end
