module DaVinciCRDTestKit
  module TaggedRequestLoadHelper
    def load_requests_for_cross_hook_analysis
      load_tagged_requests(CROSS_HOOK_ANALYSIS_TAG)
    end

    def load_interaction_group_requests
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
