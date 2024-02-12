module DaVinciCRDTestKit
  APPOINTMENT_BOOK_PATH = '/cds-services/appointment-book-service'.freeze
  ENCOUNTER_START_PATH = '/cds-services/encounter-start-service'.freeze
  ENCOUNTER_DISCHARGE_PATH = '/cds-services/encounter-discharge-service'.freeze
  ORDER_DISPATCH_PATH = '/cds-services/order-dispatch-service'.freeze
  ORDER_SELECT_PATH = '/cds-services/order-select-service'.freeze
  ORDER_SIGN_PATH = '/cds-services/order-sign-service'.freeze
  RESUME_PASS_PATH = '/resume_pass'.freeze
  RESUME_FAIL_PATH = '/resume_fail'.freeze

  module URLs
    def base_url
      @base_url ||= "#{Inferno::Application['base_url']}/custom/#{suite_id}"
    end

    def appointment_book_url
      @appointment_book_url ||= base_url + APPOINTMENT_BOOK_PATH
    end

    def encounter_start_url
      @encounter_start_url ||= base_url + ENCOUNTER_START_PATH
    end

    def encounter_discharge_url
      @encounter_discharge_url ||= base_url + ENCOUNTER_DISCHARGE_PATH
    end

    def order_dispatch_url
      @order_dispatch_url ||= base_url + ORDER_DISPATCH_PATH
    end

    def order_select_url
      @order_select_url ||= base_url + ORDER_SELECT_PATH
    end

    def order_sign_url
      @order_sign_url ||= base_url + ORDER_SIGN_PATH
    end

    def resume_pass_url
      @resume_pass_url ||= base_url + RESUME_PASS_PATH
    end

    def resume_fail_url
      @resume_fail_url ||= base_url + RESUME_FAIL_PATH
    end

    def suite_id
      self.class.suite.id
    end
  end
end
