require_relative '../cross_suite/base_urls'

module DaVinciCRDTestKit
  DISCOVERY_PATH = '/cds-services'.freeze
  APPOINTMENT_BOOK_PATH = "#{DISCOVERY_PATH}/appointment-book-service".freeze
  ENCOUNTER_START_PATH = "#{DISCOVERY_PATH}/encounter-start-service".freeze
  ENCOUNTER_DISCHARGE_PATH = "#{DISCOVERY_PATH}/encounter-discharge-service".freeze
  ORDER_DISPATCH_PATH = "#{DISCOVERY_PATH}/order-dispatch-service".freeze
  ORDER_SELECT_PATH = "#{DISCOVERY_PATH}/order-select-service".freeze
  ORDER_SIGN_PATH = "#{DISCOVERY_PATH}/order-sign-service".freeze

  PREFETCH_SUBSET_PREFIX = '/prefetch-subset'.freeze
  PREFETCH_DISCOVERY_PATH = PREFETCH_SUBSET_PREFIX + DISCOVERY_PATH
  APPOINTMENT_BOOK_PREFETCH_SUBSET_PATH = "#{PREFETCH_DISCOVERY_PATH}/appointment-book-subset".freeze
  ENCOUNTER_START_PREFETCH_SUBSET_PATH = "#{PREFETCH_DISCOVERY_PATH}/encounter-start-subset".freeze
  ENCOUNTER_DISCHARGE_PREFETCH_SUBSET_PATH = "#{PREFETCH_DISCOVERY_PATH}/encounter-discharge-subset".freeze
  ORDER_DISPATCH_PREFETCH_SUBSET_PATH = "#{PREFETCH_DISCOVERY_PATH}/order-dispatch-subset".freeze
  ORDER_SELECT_PREFETCH_SUBSET_PATH = "#{PREFETCH_DISCOVERY_PATH}/order-select-subset".freeze
  ORDER_SIGN_PREFETCH_SUBSET_PATH = "#{PREFETCH_DISCOVERY_PATH}/order-sign-subset".freeze

  module ClientBaseURLs
    include BaseURLs

    def discovery_url
      @discovery_url ||= inferno_base_url + DISCOVERY_PATH
    end

    def appointment_book_url
      @appointment_book_url ||= inferno_base_url + APPOINTMENT_BOOK_PATH
    end

    def encounter_start_url
      @encounter_start_url ||= inferno_base_url + ENCOUNTER_START_PATH
    end

    def encounter_discharge_url
      @encounter_discharge_url ||= inferno_base_url + ENCOUNTER_DISCHARGE_PATH
    end

    def order_dispatch_url
      @order_dispatch_url ||= inferno_base_url + ORDER_DISPATCH_PATH
    end

    def order_select_url
      @order_select_url ||= inferno_base_url + ORDER_SELECT_PATH
    end

    def order_sign_url
      @order_sign_url ||= inferno_base_url + ORDER_SIGN_PATH
    end

    def prefetch_subset_discovery_url
      @prefetch_subset_discovery_url ||= inferno_base_url + PREFETCH_SUBSET_PREFIX + DISCOVERY_PATH
    end

    def appointment_book_prefetch_subset_url
      @appointment_book_prefetch_subset_url ||= inferno_base_url + APPOINTMENT_BOOK_PREFETCH_SUBSET_PATH
    end

    def encounter_start_prefetch_subset_url
      @encounter_start_prefetch_subset_url ||= inferno_base_url + ENCOUNTER_START_PREFETCH_SUBSET_PATH
    end

    def encounter_discharge_prefetch_subset_url
      @encounter_discharge_prefetch_subset_url ||= inferno_base_url + ENCOUNTER_DISCHARGE_PREFETCH_SUBSET_PATH
    end

    def order_dispatch_prefetch_subset_url
      @order_dispatch_prefetch_subset_url ||= inferno_base_url + ORDER_DISPATCH_PREFETCH_SUBSET_PATH
    end

    def order_select_prefetch_subset_url
      @order_select_prefetch_subset_url ||= inferno_base_url + ORDER_SELECT_PREFETCH_SUBSET_PATH
    end

    def order_sign_prefetch_subset_url
      @order_sign_prefetch_subset_url ||= inferno_base_url + ORDER_SIGN_PREFETCH_SUBSET_PATH
    end
  end
end
