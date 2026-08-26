module DaVinciCRDTestKit
  module CrossHookHelper
    def find_completeness_tests # rubocop:disable Metrics/CyclomaticComplexity
      # minimal error checking - want it to bomb if this search logic fails
      hooks_group = self.class.parent.parent.parent.groups.find do |group|
        group.id.to_s.include?('crd_v221_client_hooks')
      end
      completeness_tests = hooks_group.groups.map do |group|
        group.groups.flat_map(&:tests).find do |test|
          test.id.to_s.include?('crd_v221_hook_request_prefetch_complete')
        end
      end

      cross_hooks_interaction_group = self.class.parent.parent.groups.find do |group|
        group.id.to_s.include?('crd_v221_client_cross_hook_interaction')
      end
      cross_hooks_completeness_test =
        cross_hooks_interaction_group.groups.flat_map(&:tests).find do |test|
          test.id.to_s.include?('crd_v221_hook_request_prefetch_complete')
        end
      completeness_tests << cross_hooks_completeness_test

      completeness_tests.compact
    end
  end
end
