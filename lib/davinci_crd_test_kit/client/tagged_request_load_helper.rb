module DaVinciCRDTestKit
  module TaggedRequestLoadHelper
    def hook_name
      config.options[:hook_name]
    end

    def crd_test_group
      config.options[:crd_test_group]
    end

    def tags_to_load
      crd_test_group.present? ? [hook_name, crd_test_group] : [hook_name]
    end

    def load_hook_requests
      load_tagged_requests(*tags_to_load)
    end
  end
end
