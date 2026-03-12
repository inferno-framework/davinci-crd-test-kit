module DaVinciCRDTestKit
  module TestHelper
    def parse_json(input)
      assert_valid_json(input)
      JSON.parse(input)
    end

    def verify_at_least_one_test_passes(test_groups, id_pattern, error_message, id_exclude_pattern = nil)
      runnables = test_groups.map do |group|
        group.tests.find do |test|
          test.id.include?(id_pattern) && (!id_exclude_pattern || !test.id.include?(id_exclude_pattern))
        end
      end.compact

      results_repo = Inferno::Repositories::Results.new
      results = results_repo.current_results_for_test_session_and_runnables(test_session_id, runnables)

      pass_if(results.any? { |result| result.result == 'pass' })

      skip error_message
    end
  end
end
