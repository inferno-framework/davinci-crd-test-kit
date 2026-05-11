require_relative '../cross_suite/base_urls'

module DaVinciCRDTestKit
  APPOINTMENT_BOOK_PATH = '/cds-services/appointment-book-service'.freeze
  ENCOUNTER_START_PATH = '/cds-services/encounter-start-service'.freeze
  ENCOUNTER_DISCHARGE_PATH = '/cds-services/encounter-discharge-service'.freeze
  ORDER_DISPATCH_PATH = '/cds-services/order-dispatch-service'.freeze
  ORDER_SELECT_PATH = '/cds-services/order-select-service'.freeze
  ORDER_SIGN_PATH = '/cds-services/order-sign-service'.freeze

  APPOINTMENT_BOOK_PREFETCH_SUBSET_PATH = '/cds-subset/appointment-book-subset'.freeze
  ENCOUNTER_START_PREFETCH_SUBSET_PATH = '/cds-subset/encounter-start-subset'.freeze
  ENCOUNTER_DISCHARGE_PREFETCH_SUBSET_PATH = '/cds-subset/encounter-discharge-subset'.freeze
  ORDER_DISPATCH_PREFETCH_SUBSET_PATH = '/cds-subset/order-dispatch-subset'.freeze
  ORDER_SELECT_PREFETCH_SUBSET_PATH = '/cds-subset/order-select-subset'.freeze
  ORDER_SIGN_PREFETCH_SUBSET_PATH = '/cds-subset/order-sign-subset'.freeze

  module ClientBaseURLs
    include BaseURLs

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
