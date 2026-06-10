module DaVinciCRDTestKit
  APPOINTMENT_BOOK_TAG = 'appointment-book'.freeze
  ENCOUNTER_START_TAG = 'encounter-start'.freeze
  ENCOUNTER_DISCHARGE_TAG = 'encounter-discharge'.freeze
  ORDER_DISPATCH_TAG = 'order-dispatch'.freeze
  ORDER_SELECT_TAG = 'order-select'.freeze
  ORDER_SIGN_TAG = 'order-sign'.freeze
  DISCOVERY_TAG = 'cds_discovery'.freeze
  ANY_HOOK_TAG = 'any_hook'.freeze
  DATA_FETCH_TAG = 'data_fetch'.freeze
  PAYER_ORG_FETCH_TAG = 'payer_org'.freeze
  PARENT_LOCATION_FETCH_TAG = 'parent_location'.freeze
  HOOK_INSTANCE_TAG_PREFIX = 'hi_'.freeze
  HOOK_INSTANCE_DATA_FETCH_TAG_PREFIX = 'hi_data_fetch_'.freeze
  LONG_RUNNING_GROUP_TAG = 'long_running_request'.freeze
  DUPLICATED_HOOK_INSTANCE_TAG = 'duplicate_hook_instance'.freeze
  COVERAGE_INFO_DISABLED_TAG = 'coverage-info-disabled'.freeze
  TECHNICAL_ISSUES_TAG = 'technical-issues'.freeze
  UNKNOWN_CONFIGURATION_TAG = 'unknown-configuration'.freeze
  UNKNOWN_CONTEXT_TAG = 'unknown-context'.freeze
  UNKNOWN_ELEMENT_TAG = 'unknown-element'.freeze

  ALL_HOOK_TAGS = [
    APPOINTMENT_BOOK_TAG,
    ENCOUNTER_START_TAG,
    ENCOUNTER_DISCHARGE_TAG,
    ORDER_DISPATCH_TAG,
    ORDER_SELECT_TAG,
    ORDER_SIGN_TAG
  ].freeze

  module TagMethods
    def hook_instance_tag(hook_instance)
      "#{HOOK_INSTANCE_TAG_PREFIX}#{hook_instance}"
    end

    def hook_instance_data_fetch_tag(hook_instance)
      "#{HOOK_INSTANCE_DATA_FETCH_TAG_PREFIX}#{hook_instance}"
    end

    module_function :hook_instance_tag, :hook_instance_data_fetch_tag
  end
end
