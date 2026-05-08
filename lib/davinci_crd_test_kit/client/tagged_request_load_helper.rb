module DaVinciCRDTestKit
  module TaggedRequestLoadHelper
    ALL_HOOKS = [
      APPOINTMENT_BOOK_TAG,
      ENCOUNTER_START_TAG,
      ENCOUNTER_DISCHARGE_TAG,
      ORDER_DISPATCH_TAG,
      ORDER_SELECT_TAG,
      ORDER_SIGN_TAG
    ].freeze

    def hook_name
      config.options[:hook_name]
    end

    def crd_test_group
      config.options[:crd_test_group]
    end

    def tags_to_load(hook = hook_name)
      crd_test_group.present? ? [crd_test_group] : [hook]
    end

    def load_hook_requests
      load_tagged_requests(*tags_to_load)
    end

    def requests_to_analyze
      if hook_name.present?
        load_tagged_requests(*tags_to_load)
      else
        ALL_HOOKS.each_with_object([]) do |hook, request_list|
          request_list.concat(load_tagged_requests(*tags_to_load(hook)))
        end
      end
    end
  end
end
