require_relative '../cross_suite/short_circuit_interaction'

module DaVinciCRDTestKit
  module TaggedRequestLoadHelper
    include ShortCircuitInteraction

    def load_requests_for_cross_hook_analysis
      load_tagged_requests(CROSS_HOOK_ANALYSIS_TAG)
    end

    # Passes rather than loading anything when the group's first test decided no requests were
    # coming, so a tester who demonstrated everything earlier is not left with skipped tests.
    def load_interaction_group_requests
      check_for_short_circuit

      load_tagged_requests(config.options[:crd_interaction_group])
    end

    def hook_name
      config.options[:hook_name]
    end

    def crd_interaction_group
      config.options[:crd_interaction_group]
    end
  end
end
